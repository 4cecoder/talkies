using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Entry point for <c>Talkies.Windows.exe --crispasr-worker</c>: hosts one CrispASR Phonon-2
    /// session in a separate process, keeps the model resident, and serves requests over two
    /// anonymous pipes. Isolating the runtime keeps its ggml DLLs away from LLamaSharp's and turns
    /// a native crash into a recoverable Whisper fallback instead of an app crash.
    /// </summary>
    internal static class CrispAsrWorker
    {
        public const string Argument = "--crispasr-worker";
        public const string BackendName = "phonon2";
        private const int ExitOk = 0;
        private const int ExitUsage = 64;
        private const int ExitLoadFailed = 65;

        public static bool IsWorkerInvocation(string[] args) =>
            args.Length > 0 && string.Equals(args[0], Argument, StringComparison.Ordinal);

        /// <summary>Arguments: --crispasr-worker &lt;in-pipe&gt; &lt;out-pipe&gt; &lt;model-path&gt; &lt;threads&gt;.</summary>
        public static int Run(string[] args)
        {
            if (args.Length != 5 || !int.TryParse(args[4], NumberStyles.None, CultureInfo.InvariantCulture, out var threads) || threads < 1)
                return ExitUsage;

            using var input = new AnonymousPipeClientStream(PipeDirection.In, args[1]);
            using var output = new AnonymousPipeClientStream(PipeDirection.Out, args[2]);
            using var reader = new BinaryReader(input);
            using var writer = new BinaryWriter(output);

            var session = IntPtr.Zero;
            var helloSent = false;
            try
            {
                CrispAsrNative.UseRuntimeDirectory(CrispAsrRuntime.RuntimeDirectory);
                session = CrispAsrNative.crispasr_session_open_explicit(args[3], BackendName, threads);
                if (session == IntPtr.Zero)
                {
                    CrispAsrWorkerProtocol.WriteHello(writer, false, "CrispASR could not load the Phonon-2 model.");
                    return ExitLoadFailed;
                }

                var backend = Marshal.PtrToStringUTF8(CrispAsrNative.crispasr_session_backend(session)) ?? BackendName;
                CrispAsrWorkerProtocol.WriteHello(writer, true, $"CrispASR {CrispAsrRuntime.Version} ({backend}, CPU)");
                helloSent = true;

                while (CrispAsrWorkerProtocol.ReadRequest(reader) is { } request)
                {
                    try
                    {
                        CrispAsrWorkerProtocol.WriteResult(writer, Transcribe(session, request.Samples, request.Language));
                    }
                    catch (InvalidOperationException ex)
                    {
                        CrispAsrWorkerProtocol.WriteError(writer, ex.Message);
                    }
                }
                return ExitOk;
            }
            catch (Exception ex) when (!helloSent && ex is DllNotFoundException or EntryPointNotFoundException or BadImageFormatException)
            {
                TryWriteHello(writer, $"CrispASR runtime could not be loaded: {ex.Message}");
                return ExitLoadFailed;
            }
            catch (IOException)
            {
                // The app closed the pipe (exit or restart); nothing left to report to.
                return ExitOk;
            }
            finally
            {
                if (session != IntPtr.Zero) CrispAsrNative.crispasr_session_close(session);
            }
        }

        private static IReadOnlyList<CrispAsrSegment> Transcribe(IntPtr session, float[] samples, string language)
        {
            if (samples.Length == 0) return Array.Empty<CrispAsrSegment>();

            var result = CrispAsrNative.crispasr_session_transcribe_lang(session, samples, samples.Length, language);
            if (result == IntPtr.Zero)
                throw new InvalidOperationException("CrispASR returned no Phonon-2 result.");

            try
            {
                var count = CrispAsrNative.crispasr_session_result_n_segments(result);
                if (count < 0 || count > CrispAsrWorkerProtocol.MaxSegments)
                    throw new InvalidOperationException($"CrispASR returned an invalid segment count ({count}).");

                var segments = new List<CrispAsrSegment>(count);
                for (var i = 0; i < count; i++)
                {
                    var text = Marshal.PtrToStringUTF8(CrispAsrNative.crispasr_session_result_segment_text(result, i)) ?? string.Empty;
                    segments.Add(new CrispAsrSegment(
                        text,
                        CrispAsrNative.crispasr_session_result_segment_t0(result, i),
                        CrispAsrNative.crispasr_session_result_segment_t1(result, i)));
                }
                return segments;
            }
            finally
            {
                CrispAsrNative.crispasr_session_result_free(result);
            }
        }

        private static void TryWriteHello(BinaryWriter writer, string message)
        {
            try
            {
                CrispAsrWorkerProtocol.WriteHello(writer, false, message);
            }
            catch (IOException)
            {
                // The app is gone.
            }
        }
    }
}
