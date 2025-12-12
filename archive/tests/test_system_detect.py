"""
Tests for system detection
"""

import pytest
from whisper_cli.system_detect import SystemDetector, get_system_info


def test_system_detector_initialization():
    """Test that SystemDetector can be initialized"""
    detector = SystemDetector()
    assert detector is not None


def test_get_system_info():
    """Test getting system information"""
    info = get_system_info()
    assert isinstance(info, dict)
    assert 'os' in info
    assert 'architecture' in info
    assert 'python_version' in info


def test_os_detection():
    """Test OS detection"""
    detector = SystemDetector()
    os_info = detector.info['os']
    assert 'system' in os_info
    assert os_info['is_windows'] or os_info['is_macos'] or os_info['is_linux']


def test_architecture_detection():
    """Test architecture detection"""
    detector = SystemDetector()
    arch_info = detector.info['architecture']
    assert 'machine' in arch_info
    assert arch_info['is_x86_64'] or arch_info['is_arm64'] or arch_info['is_arm']


def test_python_version_detection():
    """Test Python version detection"""
    detector = SystemDetector()
    py_info = detector.info['python_version']
    assert 'version' in py_info
    assert py_info['major'] >= 3


def test_hardware_detection():
    """Test hardware detection"""
    detector = SystemDetector()
    hw_info = detector.info['hardware']
    assert 'cpu_count' in hw_info
    assert isinstance(hw_info['cpu_count'], int)


def test_paths_detection():
    """Test system paths detection"""
    detector = SystemDetector()
    paths_info = detector.info['paths']
    assert 'home' in paths_info
    assert 'config' in paths_info