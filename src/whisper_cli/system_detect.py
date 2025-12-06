"""
System detection utilities for platform-specific functionality
"""

import platform
import sys
import os
import subprocess
from typing import Dict, Any, Optional
import psutil
import requests
from pathlib import Path

class SystemDetector:
    """Detect system information and capabilities"""

    def __init__(self):
        self._info = None

    @property
    def info(self) -> Dict[str, Any]:
        """Get comprehensive system information"""
        if self._info is None:
            self._info = self._detect_system()
        return self._info

    def _detect_system(self) -> Dict[str, Any]:
        """Detect all system information"""
        info = {
            'os': self._detect_os(),
            'architecture': self._detect_architecture(),
            'python_version': self._detect_python_version(),
            'hardware': self._detect_hardware(),
            'audio': self._detect_audio(),
            'local_ai': self._detect_local_ai(),
            'gpu': self._detect_gpu(),
            'memory': self._detect_memory(),
            'paths': self._detect_paths(),
        }
        return info

    def _detect_os(self) -> Dict[str, str]:
        """Detect operating system details"""
        system = platform.system().lower()
        release = platform.release()
        version = platform.version()

        os_info = {
            'system': system,
            'release': release,
            'version': version,
            'is_windows': system == 'windows',
            'is_macos': system == 'darwin',
            'is_linux': system == 'linux',
            'is_unix': system in ['linux', 'darwin'],
        }

        # macOS specific
        if os_info['is_macos']:
            os_info.update(self._detect_macos_version())

        return os_info

    def _detect_macos_version(self) -> Dict[str, str]:
        """Detect macOS version details"""
        try:
            result = subprocess.run(['sw_vers'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                version_info = {}
                for line in lines:
                    if ': ' in line:
                        key, value = line.split(': ', 1)
                        version_info[key.lower().replace(' ', '_')] = value
                return version_info
        except Exception:
            pass
        return {}

    def _detect_architecture(self) -> Dict[str, str]:
        """Detect system architecture"""
        machine = platform.machine().lower()
        processor = platform.processor()

        arch_info = {
            'machine': machine,
            'processor': processor,
            'is_x86_64': machine in ['x86_64', 'amd64'],
            'is_arm64': machine in ['arm64', 'aarch64'],
            'is_arm': machine.startswith('arm'),
            'is_intel': 'intel' in processor.lower() or machine in ['x86_64', 'amd64'],
            'is_apple_silicon': machine == 'arm64' and platform.system() == 'Darwin',
        }

        return arch_info

    def _detect_python_version(self) -> Dict[str, Any]:
        """Detect Python version information"""
        return {
            'version': sys.version,
            'version_info': sys.version_info,
            'major': sys.version_info.major,
            'minor': sys.version_info.minor,
            'micro': sys.version_info.micro,
            'is_64bit': sys.maxsize > 2**32,
        }

    def _detect_hardware(self) -> Dict[str, Any]:
        """Detect hardware information"""
        try:
            return {
                'cpu_count': psutil.cpu_count(),
                'cpu_count_logical': psutil.cpu_count(logical=True),
                'cpu_freq': psutil.cpu_freq().current if psutil.cpu_freq() else None,
                'cpu_percent': psutil.cpu_percent(interval=1),
            }
        except Exception:
            return {
                'cpu_count': os.cpu_count(),
                'cpu_count_logical': os.cpu_count(),
                'cpu_freq': None,
                'cpu_percent': None,
            }

    def _detect_gpu(self) -> Dict[str, Any]:
        """Detect GPU information"""
        gpu_info = {
            'has_cuda': False,
            'cuda_version': None,
            'has_rocm': False,
            'gpu_count': 0,
            'gpu_names': [],
        }

        # Check for CUDA
        try:
            import torch
            gpu_info['has_cuda'] = torch.cuda.is_available()
            gpu_info['gpu_count'] = torch.cuda.device_count()
            gpu_info['gpu_names'] = [torch.cuda.get_device_name(i) for i in range(gpu_info['gpu_count'])]
        except ImportError:
            pass

        # Check for ROCm (AMD)
        if not gpu_info['has_cuda']:
            try:
                # Try to detect ROCm
                result = subprocess.run(['rocminfo'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    gpu_info['has_rocm'] = True
            except Exception:
                pass

        return gpu_info

    def _detect_memory(self) -> Dict[str, Any]:
        """Detect memory information"""
        try:
            mem = psutil.virtual_memory()
            return {
                'total': mem.total,
                'available': mem.available,
                'percent': mem.percent,
                'used': mem.used,
            }
        except Exception:
            return {}

    def _detect_audio(self) -> Dict[str, Any]:
        """Detect audio capabilities"""
        audio_info = {
            'has_pyaudio': False,
            'has_sounddevice': False,
            'input_devices': [],
            'output_devices': [],
            'default_input': None,
            'default_output': None,
        }

        # Check available audio libraries
        try:
            import pyaudio
            audio_info['has_pyaudio'] = True
        except ImportError:
            pass

        try:
            import sounddevice as sd
            audio_info['has_sounddevice'] = True
            try:
                devices = sd.query_devices()
                audio_info['input_devices'] = [d['name'] for d in devices if d['max_input_channels'] > 0]
                audio_info['output_devices'] = [d['name'] for d in devices if d['max_output_channels'] > 0]
                audio_info['default_input'] = sd.default.device[0] if sd.default.device else None
                audio_info['default_output'] = sd.default.device[1] if sd.default.device else None
            except Exception:
                pass
        except ImportError:
            pass

        return audio_info

    def _detect_local_ai(self) -> Dict[str, Any]:
        """Detect available local AI services"""
        local_ai = {
            'ollama': self._check_ollama(),
            'lmstudio': self._check_lmstudio(),
            'available_services': [],
        }

        if local_ai['ollama']['available']:
            local_ai['available_services'].append('ollama')
        if local_ai['lmstudio']['available']:
            local_ai['available_services'].append('lmstudio')

        return local_ai

    def _check_ollama(self) -> Dict[str, Any]:
        """Check if Ollama is available"""
        ollama_info = {
            'available': False,
            'version': None,
            'models': [],
            'url': 'http://localhost:11434',
        }

        # Check if Ollama process is running
        try:
            for proc in psutil.process_iter(['pid', 'name']):
                if 'ollama' in proc.info['name'].lower():
                    ollama_info['available'] = True
                    break
        except Exception:
            pass

        # Try to connect to Ollama API
        if not ollama_info['available']:
            try:
                response = requests.get(f"{ollama_info['url']}/api/tags", timeout=2)
                if response.status_code == 200:
                    ollama_info['available'] = True
                    data = response.json()
                    ollama_info['models'] = [model['name'] for model in data.get('models', [])]
            except Exception:
                pass

        return ollama_info

    def _check_lmstudio(self) -> Dict[str, Any]:
        """Check if LM Studio is available"""
        lmstudio_info = {
            'available': False,
            'version': None,
            'url': 'http://localhost:1234',
        }

        # Check if LM Studio process is running
        try:
            for proc in psutil.process_iter(['pid', 'name']):
                if 'lm studio' in proc.info['name'].lower() or 'lm-studio' in proc.info['name'].lower():
                    lmstudio_info['available'] = True
                    break
        except Exception:
            pass

        # Try to connect to LM Studio API
        if not lmstudio_info['available']:
            try:
                # LM Studio uses OpenAI-compatible API
                response = requests.get(f"{lmstudio_info['url']}/v1/models", timeout=2)
                if response.status_code == 200:
                    lmstudio_info['available'] = True
            except Exception:
                pass

        return lmstudio_info

    def _detect_paths(self) -> Dict[str, str]:
        """Detect system-specific paths"""
        paths = {
            'home': str(Path.home()),
            'config': str(Path.home() / '.whisper-cli.toml'),
            'cache': str(Path.home() / '.cache' / 'whisper-cli'),
            'temp': str(Path.home() / 'tmp' if platform.system() == 'Windows' else '/tmp'),
        }

        # OS-specific paths
        if platform.system() == 'Windows':
            paths.update({
                'app_data': os.environ.get('APPDATA', ''),
                'local_app_data': os.environ.get('LOCALAPPDATA', ''),
            })
        elif platform.system() == 'Darwin':  # macOS
            paths.update({
                'application_support': str(Path.home() / 'Library' / 'Application Support' / 'WhisperCLI'),
                'preferences': str(Path.home() / 'Library' / 'Preferences'),
            })
        else:  # Linux/Unix
            paths.update({
                'config_dir': os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')),
                'cache_dir': os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache')),
                'data_dir': os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local' / 'share')),
            })

        return paths

    def get_recommended_config(self) -> Dict[str, Any]:
        """Get recommended configuration based on system detection"""
        config = {}

        # GPU settings
        if self.info['gpu']['has_cuda']:
            config['whisper'] = {'device': 'cuda'}
        elif self.info['gpu']['has_rocm']:
            config['whisper'] = {'device': 'cuda'}  # ROCm works with CUDA device in some cases
        else:
            config['whisper'] = {'device': 'cpu'}

        # Audio settings based on available libraries
        if self.info['audio']['has_sounddevice']:
            config['recording'] = {'backend': 'sounddevice'}
        elif self.info['audio']['has_pyaudio']:
            config['recording'] = {'backend': 'pyaudio'}

        # Local AI settings
        if self.info['local_ai']['ollama']['available']:
            config['ai_services'] = {'ollama_url': 'http://localhost:11434'}
        elif self.info['local_ai']['lmstudio']['available']:
            config['ai_services'] = {'lmstudio_url': 'http://localhost:1234'}

        return config

    def print_system_info(self):
        """Print formatted system information"""
        info = self.info

        print("=== System Information ===")
        print(f"OS: {info['os']['system']} {info['os']['release']}")
        print(f"Architecture: {info['architecture']['machine']}")
        print(f"Python: {info['python_version']['version']}")
        print(f"CPU: {info['hardware']['cpu_count']} cores")
        print(f"Memory: {info['memory'].get('total', 'Unknown')} bytes")

        if info['gpu']['gpu_count'] > 0:
            print(f"GPU: {info['gpu']['gpu_names'][0]}")
        else:
            print("GPU: None detected")

        print(f"Audio: {'Available' if info['audio']['has_pyaudio'] or info['audio']['has_sounddevice'] else 'Not available'}")

        local_ai = info['local_ai']
        if local_ai['available_services']:
            print(f"Local AI: {', '.join(local_ai['available_services'])}")
        else:
            print("Local AI: None detected")

# Global instance
system_detector = SystemDetector()

def get_system_info() -> Dict[str, Any]:
    """Get system information"""
    return system_detector.info

def get_recommended_config() -> Dict[str, Any]:
    """Get recommended configuration for this system"""
    return system_detector.get_recommended_config()

def print_system_info():
    """Print system information"""
    system_detector.print_system_info()

if __name__ == "__main__":
    print_system_info()