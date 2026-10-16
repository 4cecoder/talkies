using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;

namespace Talkies.Windows.Services
{
    /// <summary>App-side handle to one running <see cref="CrispAsrWorker"/> process.</summary>
    internal sealed class CrispAsrWorkerProcess : IDisposable
    {
        private readonly Process _process;
        private readonly AnonymousPipeServerStream _toWorker;
        private readonly AnonymousPipeServerStream _fromWorker;
        private readonly BinaryWriter _writer;
        private readonly BinaryReader _reader;
        private int _disposed;

        private CrispAsrWorkerProcess(Process process, AnonymousPipeServerStream toWorker, AnonymousPipeServerStream fromWorker)
        {
            _process = process;
            _toWorker = toWorker;
            _fromWorker = fromWorker;
            _writer = new BinaryWriter(toWorker);
            _reader = new BinaryReader(fromWorker);
        }

        public string RuntimeDescription { get; private set; } = "CrispASR";
        public bool HasExited => Volatile.Read(ref _disposed) != 0 || _process.HasExited;

        /// <summary>Starts the worker and waits until it has loaded the model or reported why it could not.</summary>
        public static async Task<CrispAsrWorkerProcess> StartAsync(string modelPath, int threads, TimeSpan loadTimeout, CancellationToken cancellationToken)
        {
            var executable = Environment.ProcessPath;
            if (string.IsNullOrEmpty(executable) || !File.Exists(executable))
                throw new InvalidOperationException("Cannot locate Talkies.Windows.exe to start the Phonon-2 worker.");

            var toWorker = new AnonymousPipeServerStream(PipeDirection.Out, HandleInheritability.Inheritable);
            var fromWorker = new AnonymousPipeServerStream(PipeDirection.In, HandleInheritability.Inheritable);
            Process? process = null;
            try
            {
                var startInfo = new ProcessStartInfo(executable)
                {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WorkingDirectory = CrispAsrRuntime.RuntimeDirectory,
                };
                startInfo.ArgumentList.Add(CrispAsrWorker.Argument);
                startInfo.ArgumentList.Add(toWorker.GetClientHandleAsString());
                startInfo.ArgumentList.Add(fromWorker.GetClientHandleAsString());
                startInfo.ArgumentList.Add(modelPath);
                startInfo.ArgumentList.Add(threads.ToString(CultureInfo.InvariantCulture));

                process = Process.Start(startInfo) ?? throw new InvalidOperationException("The Phonon-2 worker did not start.");
                // Drop our copies of the child's ends so a worker exit surfaces as end-of-stream.
                toWorker.DisposeLocalCopyOfClientHandle();
                fromWorker.DisposeLocalCopyOfClientHandle();

                var worker = new CrispAsrWorkerProcess(process, toWorker, fromWorker);
                try
                {
                    var (ok, message) = await worker.RunBoundedAsync(() => CrispAsrWorkerProtocol.ReadHello(worker._reader), loadTimeout, "load Phonon-2", cancellationToken).ConfigureAwait(false);
                    if (!ok) throw new InvalidOperationException(message);
                    worker.RuntimeDescription = message;
                    return worker;
                }
                catch
                {
                    worker.Dispose();
                    throw;
                }
            }
            catch when (process is null)
            {
                toWorker.Dispose();
                fromWorker.Dispose();
                throw;
            }
        }

        public Task<IReadOnlyList<CrispAsrSegment>> TranscribeAsync(float[] samples, string language, TimeSpan timeout, CancellationToken cancellationToken) =>
            RunBoundedAsync(() =>
            {
                CrispAsrWorkerProtocol.WriteTranscribeRequest(_writer, language, samples);
                return CrispAsrWorkerProtocol.ReadResponse(_reader);
            }, timeout, "transcribe with Phonon-2", cancellationToken);

        /// <summary>
        /// Runs blocking pipe I/O off the caller's thread. On timeout, cancellation, or a broken pipe the
        /// worker is killed (which also unblocks the read) and the error is surfaced to the fallback chain.
        /// </summary>
        private async Task<T> RunBoundedAsync<T>(Func<T> operation, TimeSpan timeout, string action, CancellationToken cancellationToken)
        {
            var task = Task.Run(operation, CancellationToken.None);
            try
            {
                return await task.WaitAsync(timeout, cancellationToken).ConfigureAwait(false);
            }
            catch (TimeoutException)
            {
                Terminate(graceful: false);
                throw new TimeoutException($"Phonon-2 did not {action} within {timeout.TotalSeconds:F0} seconds.");
            }
            catch (OperationCanceledException)
            {
                Terminate(graceful: false);
                throw;
            }
            catch (Exception ex) when (ex is IOException or EndOfStreamException or ObjectDisposedException)
            {
                var exitCode = SafeExitCode();
                Terminate(graceful: false);
                throw new InvalidOperationException($"The Phonon-2 worker stopped unexpectedly while trying to {action}{exitCode}.", ex);
            }
        }

        private string SafeExitCode()
        {
            try
            {
                return _process.WaitForExit(2000) ? $" (exit code {_process.ExitCode})" : string.Empty;
            }
            catch (InvalidOperationException)
            {
                return string.Empty;
            }
        }

        public void Dispose() => Terminate(graceful: true);

        private void Terminate(bool graceful)
        {
            if (Interlocked.Exchange(ref _disposed, 1) != 0) return;
            try
            {
                if (!_process.HasExited && !graceful)
                {
                    _process.Kill(entireProcessTree: true);
                }
                else if (!_process.HasExited)
                {
                    try
                    {
                        CrispAsrWorkerProtocol.WriteShutdown(_writer);
                    }
                    catch (IOException)
                    {
                        // Pipe already broken.
                    }
                    catch (ObjectDisposedException)
                    {
                        // Pipe already closed.
                    }

                    if (!_process.WaitForExit(2000))
                        _process.Kill(entireProcessTree: true);
                }
            }
            catch (InvalidOperationException)
            {
                // Process already gone.
            }
            finally
            {
                _toWorker.Dispose();
                _fromWorker.Dispose();
                _process.Dispose();
            }
        }
    }
}
