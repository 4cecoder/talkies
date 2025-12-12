using System.Collections.Generic;
using System.Linq;
using NAudio.CoreAudioApi;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public interface IAudioDeviceService
    {
        List<AudioDeviceInfo> GetCaptureDevices();
        AudioDeviceInfo? GetDefaultCaptureDevice();
    }

    public class AudioDeviceService : IAudioDeviceService
    {
        public List<AudioDeviceInfo> GetCaptureDevices()
        {
            using var enumerator = new MMDeviceEnumerator();
            var coll = enumerator.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active);
            var devices = coll
                .Select(d => new AudioDeviceInfo { Id = d.ID, Name = d.FriendlyName })
                .ToList();

            // Add virtual system audio (loopback) at the top
            devices.Insert(0, new AudioDeviceInfo { Id = "__loopback", Name = "System Audio (Loopback)" });
            return devices;
        }

        public AudioDeviceInfo? GetDefaultCaptureDevice()
        {
            using var enumerator = new MMDeviceEnumerator();
            var def = enumerator.GetDefaultAudioEndpoint(DataFlow.Capture, Role.Communications);
            return def == null ? null : new AudioDeviceInfo { Id = def.ID, Name = def.FriendlyName };
        }
    }
}
