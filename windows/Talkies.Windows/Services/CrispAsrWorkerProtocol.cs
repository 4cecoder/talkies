using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

namespace Talkies.Windows.Services
{
    /// <summary>One recognized segment, with CrispASR's centisecond timestamps.</summary>
    internal sealed record CrispAsrSegment(string Text, long StartCentiseconds, long EndCentiseconds);

    /// <summary>Framing for the Talkies to CrispASR-worker pipes. Little-endian, versioned, bounded.</summary>
    internal static class CrispAsrWorkerProtocol
    {
        public const int Magic = 0x3248_5054; // "TPH2" little-endian
        public const int Version = 1;

        /// <summary>Upper bound on one request: 30 minutes of 16 kHz audio.</summary>
        public const int MaxSamples = 16_000 * 60 * 30;
        public const int MaxSegments = 100_000;
        public const int MaxStringBytes = 1 << 20;

        private const int OpShutdown = 0;
        private const int OpTranscribe = 1;
        private const int StatusOk = 0;
        private const int StatusError = 1;

        public static void WriteHello(BinaryWriter writer, bool ok, string message)
        {
            writer.Write(Magic);
            writer.Write(Version);
            writer.Write(ok ? StatusOk : StatusError);
            WriteString(writer, message);
            writer.Flush();
        }

        /// <summary>Reads the worker's ready message. Throws when the worker speaks another protocol.</summary>
        public static (bool Ok, string Message) ReadHello(BinaryReader reader)
        {
            if (reader.ReadInt32() != Magic) throw new InvalidDataException("CrispASR worker sent an unexpected handshake.");
            var version = reader.ReadInt32();
            if (version != Version) throw new InvalidDataException($"CrispASR worker protocol {version} is not supported (expected {Version}).");
            var status = reader.ReadInt32();
            return (status == StatusOk, ReadString(reader));
        }

        public static void WriteTranscribeRequest(BinaryWriter writer, string language, ReadOnlySpan<float> samples)
        {
            if (samples.Length > MaxSamples) throw new ArgumentOutOfRangeException(nameof(samples), "Recording is longer than the 30 minute Phonon-2 request limit.");
            writer.Write(OpTranscribe);
            WriteString(writer, language);
            writer.Write(samples.Length);
            writer.Flush();
            writer.BaseStream.Write(MemoryMarshal.AsBytes(samples));
            writer.BaseStream.Flush();
        }

        public static void WriteShutdown(BinaryWriter writer)
        {
            writer.Write(OpShutdown);
            writer.Flush();
        }

        /// <summary>Returns null for shutdown or a closed pipe; otherwise the language and samples to transcribe.</summary>
        public static (string Language, float[] Samples)? ReadRequest(BinaryReader reader)
        {
            int op;
            try
            {
                op = reader.ReadInt32();
            }
            catch (EndOfStreamException)
            {
                return null;
            }

            if (op == OpShutdown) return null;
            if (op != OpTranscribe) throw new InvalidDataException($"Unknown CrispASR worker request {op}.");

            var language = ReadString(reader);
            var count = reader.ReadInt32();
            if (count < 0 || count > MaxSamples) throw new InvalidDataException($"Invalid sample count {count}.");
            var samples = new float[count];
            reader.BaseStream.ReadExactly(MemoryMarshal.AsBytes(samples.AsSpan()));
            return (language, samples);
        }

        public static void WriteResult(BinaryWriter writer, IReadOnlyList<CrispAsrSegment> segments)
        {
            writer.Write(StatusOk);
            writer.Write(segments.Count);
            foreach (var segment in segments)
            {
                WriteString(writer, segment.Text);
                writer.Write(segment.StartCentiseconds);
                writer.Write(segment.EndCentiseconds);
            }
            writer.Flush();
        }

        public static void WriteError(BinaryWriter writer, string message)
        {
            writer.Write(StatusError);
            WriteString(writer, message);
            writer.Flush();
        }

        /// <summary>Reads one response; a worker-reported error becomes an <see cref="InvalidOperationException"/>.</summary>
        public static IReadOnlyList<CrispAsrSegment> ReadResponse(BinaryReader reader)
        {
            var status = reader.ReadInt32();
            if (status == StatusError) throw new InvalidOperationException(ReadString(reader));
            if (status != StatusOk) throw new InvalidDataException($"Unknown CrispASR worker status {status}.");

            var count = reader.ReadInt32();
            if (count < 0 || count > MaxSegments) throw new InvalidDataException($"Invalid segment count {count}.");
            var segments = new List<CrispAsrSegment>(count);
            for (var i = 0; i < count; i++)
                segments.Add(new CrispAsrSegment(ReadString(reader), reader.ReadInt64(), reader.ReadInt64()));
            return segments;
        }

        private static void WriteString(BinaryWriter writer, string value)
        {
            var bytes = System.Text.Encoding.UTF8.GetBytes(value ?? string.Empty);
            if (bytes.Length > MaxStringBytes) throw new ArgumentOutOfRangeException(nameof(value), "Protocol string is too long.");
            writer.Write(bytes.Length);
            writer.Write(bytes);
        }

        private static string ReadString(BinaryReader reader)
        {
            var length = reader.ReadInt32();
            if (length < 0 || length > MaxStringBytes) throw new InvalidDataException($"Invalid string length {length}.");
            var bytes = reader.ReadBytes(length);
            if (bytes.Length != length) throw new EndOfStreamException();
            return System.Text.Encoding.UTF8.GetString(bytes);
        }
    }
}
