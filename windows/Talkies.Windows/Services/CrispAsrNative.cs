using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Talkies.Windows.Services
{
    /// <summary>Location and pinned identity of the bundled CrispASR native runtime.</summary>
    internal static class CrispAsrRuntime
    {
        public const string Version = "0.8.43";

        /// <summary>Commit the v0.8.43 annotated tag (object 602a9888…) points to.</summary>
        public const string Commit = "eb633d908120cc5f44b8af8cd4aeb1191f16bfd8";

        /// <summary>
        /// CrispASR ships unrenamed ggml.dll / ggml-base.dll / ggml-cpu.dll, the same module names
        /// LLamaSharp loads for S1-mini. Windows reuses an already-loaded module with the same name,
        /// so CrispASR lives in its own folder and only ever loads inside the worker process.
        /// </summary>
        public const string DirectoryName = "crispasr";
        public const string LibraryFileName = "crispasr.dll";

        public static string RuntimeDirectory => Path.Combine(AppContext.BaseDirectory, DirectoryName);
        public static string LibraryPath => Path.Combine(RuntimeDirectory, LibraryFileName);
        public static bool IsPresent => File.Exists(LibraryPath);
    }

    /// <summary>
    /// P/Invoke declarations for the CrispASR session C ABI (include/crispasr_session.h at
    /// <see cref="CrispAsrRuntime.Commit"/>). Only call these from the worker process.
    /// </summary>
    internal static class CrispAsrNative
    {
        private const string Library = "crispasr";
        private static int _resolverInstalled;

        /// <summary>Resolves "crispasr" to the bundled runtime folder so its ggml DLLs load beside it.</summary>
        public static void UseRuntimeDirectory(string runtimeDirectory)
        {
            var libraryPath = Path.Combine(runtimeDirectory, CrispAsrRuntime.LibraryFileName);
            if (!File.Exists(libraryPath))
                throw new DllNotFoundException($"CrispASR runtime not found at {libraryPath}.");

            if (OperatingSystem.IsWindows())
                SetDllDirectoryW(runtimeDirectory);

            if (System.Threading.Interlocked.Exchange(ref _resolverInstalled, 1) == 0)
            {
                NativeLibrary.SetDllImportResolver(typeof(CrispAsrNative).Assembly, (name, _, _) =>
                    string.Equals(name, Library, StringComparison.Ordinal) ? NativeLibrary.Load(libraryPath) : IntPtr.Zero);
            }
        }

        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetDllDirectoryW(string lpPathName);

        // crispasr_session* crispasr_session_open_explicit(const char* model_path, const char* backend_name, int n_threads);
        // Returns NULL when the backend is unknown/not compiled in or the model fails to load.
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern IntPtr crispasr_session_open_explicit(
            [MarshalAs(UnmanagedType.LPUTF8Str)] string modelPath,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string backendName,
            int nThreads);

        // const char* crispasr_session_backend(crispasr_session* s);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern IntPtr crispasr_session_backend(IntPtr session);

        // crispasr_session_result* crispasr_session_transcribe_lang(crispasr_session* s, const float* pcm, int n_samples, const char* language);
        // 16 kHz mono float PCM. Returns NULL on failure (including a language the backend cannot honour).
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern IntPtr crispasr_session_transcribe_lang(
            IntPtr session,
            float[] pcm,
            int nSamples,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string language);

        // int crispasr_session_result_n_segments(crispasr_session_result* r);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern int crispasr_session_result_n_segments(IntPtr result);

        // const char* crispasr_session_result_segment_text(crispasr_session_result* r, int i); valid UTF-8, owned by the result.
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern IntPtr crispasr_session_result_segment_text(IntPtr result, int index);

        // int64_t crispasr_session_result_segment_t0/t1(crispasr_session_result* r, int i); centiseconds.
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern long crispasr_session_result_segment_t0(IntPtr result, int index);

        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern long crispasr_session_result_segment_t1(IntPtr result, int index);

        // void crispasr_session_result_free(crispasr_session_result* r);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern void crispasr_session_result_free(IntPtr result);

        // void crispasr_session_close(crispasr_session* s);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        public static extern void crispasr_session_close(IntPtr session);
    }
}
