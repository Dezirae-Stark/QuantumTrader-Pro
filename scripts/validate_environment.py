#!/usr/bin/env python3
"""
QuantumTrader-Pro Environment Validator
Checks all prerequisites and configurations for running the system
"""

import os
import sys
import subprocess
import json
import platform
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

class EnvironmentValidator:
    def __init__(self):
        self.results = {
            'system': {},
            'python': {},
            'node': {},
            'flutter': {},
            'android': {},
            'dependencies': {},
            'configuration': {},
            'connectivity': {}
        }
        self.warnings = []
        self.errors = []
        
    def print_header(self, text: str):
        print(f"\n{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}")
        print(f"{Colors.BLUE}{Colors.BOLD}{text.center(60)}{Colors.END}")
        print(f"{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}")
    
    def print_status(self, component: str, status: bool, message: str = ""):
        if status:
            print(f"{Colors.GREEN}✓{Colors.END} {component:<30} {Colors.GREEN}OK{Colors.END} {message}")
        else:
            print(f"{Colors.RED}✗{Colors.END} {component:<30} {Colors.RED}FAIL{Colors.END} {message}")
            
    def print_warning(self, message: str):
        print(f"{Colors.YELLOW}⚠{Colors.END}  {message}")
        self.warnings.append(message)
        
    def run_command(self, command: List[str], capture: bool = True) -> Tuple[bool, str]:
        """Run a command and return success status and output"""
        try:
            if capture:
                result = subprocess.run(command, capture_output=True, text=True)
                return result.returncode == 0, result.stdout.strip()
            else:
                result = subprocess.run(command)
                return result.returncode == 0, ""
        except FileNotFoundError:
            return False, "Command not found"
        except Exception as e:
            return False, str(e)
    
    def check_system(self):
        """Check system requirements"""
        self.print_header("System Requirements")
        
        # OS Check
        os_name = platform.system()
        os_version = platform.version()
        self.results['system']['os'] = os_name
        self.results['system']['os_version'] = os_version
        
        supported_os = os_name in ['Windows', 'Darwin', 'Linux']
        self.print_status("Operating System", supported_os, f"{os_name} {os_version}")
        
        # CPU Check
        cpu_count = os.cpu_count()
        self.results['system']['cpu_cores'] = cpu_count
        cpu_ok = cpu_count >= 4
        self.print_status("CPU Cores", cpu_ok, f"{cpu_count} cores")
        
        # Memory Check (Python doesn't have direct memory access, so we use psutil if available)
        try:
            import psutil
            memory_gb = psutil.virtual_memory().total / (1024**3)
            self.results['system']['memory_gb'] = memory_gb
            mem_ok = memory_gb >= 8
            self.print_status("Memory", mem_ok, f"{memory_gb:.1f} GB")
        except ImportError:
            self.print_warning("Install psutil for memory check: pip install psutil")
            
        # Disk Space
        disk_usage = os.stakedisk_usage('.')
        free_gb = disk_usage.free / (1024**3)
        self.results['system']['disk_free_gb'] = free_gb
        disk_ok = free_gb >= 10
        self.print_status("Disk Space", disk_ok, f"{free_gb:.1f} GB free")
        
    def check_python(self):
        """Check Python environment"""
        self.print_header("Python Environment")
        
        # Python Version
        python_version = sys.version_info
        version_str = f"{python_version.major}.{python_version.minor}.{python_version.patch}"
        self.results['python']['version'] = version_str
        py_ok = python_version >= (3, 8)
        self.print_status("Python Version", py_ok, version_str)
        
        # Virtual Environment
        in_venv = hasattr(sys, 'real_prefix') or (
            hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix
        )
        self.results['python']['virtual_env'] = in_venv
        self.print_status("Virtual Environment", in_venv, 
                         "Active" if in_venv else "Not active (recommended)")
        
        # Check pip
        pip_ok, pip_version = self.run_command(['pip', '--version'])
        self.results['python']['pip'] = pip_ok
        self.print_status("pip", pip_ok, pip_version.split()[1] if pip_ok else "Not found")
        
        # Check key Python packages
        packages = {
            'numpy': 'numpy',
            'pandas': 'pandas',
            'tensorflow': 'tensorflow',
            'flask': 'Flask',
            'websocket-client': 'websocket'
        }
        
        print("\nPython Packages:")
        for display_name, import_name in packages.items():
            try:
                module = __import__(import_name)
                version = getattr(module, '__version__', 'installed')
                self.print_status(f"  {display_name}", True, version)
                self.results['python'][f'package_{import_name}'] = version
            except ImportError:
                self.print_status(f"  {display_name}", False, "Not installed")
                self.results['python'][f'package_{import_name}'] = None
        
    def check_node(self):
        """Check Node.js environment"""
        self.print_header("Node.js Environment")
        
        # Node.js Version
        node_ok, node_version = self.run_command(['node', '--version'])
        self.results['node']['version'] = node_version
        self.print_status("Node.js", node_ok, node_version)
        
        if node_ok:
            # Check version number
            try:
                major_version = int(node_version.split('.')[0].replace('v', ''))
                if major_version < 16:
                    self.print_warning(f"Node.js {node_version} is old. Recommend v16+")
            except:
                pass
        
        # npm Version
        npm_ok, npm_version = self.run_command(['npm', '--version'])
        self.results['node']['npm_version'] = npm_version
        self.print_status("npm", npm_ok, npm_version)
        
        # Check if bridge dependencies are installed
        bridge_path = Path('bridge/node_modules')
        deps_installed = bridge_path.exists()
        self.results['node']['dependencies_installed'] = deps_installed
        self.print_status("Bridge Dependencies", deps_installed,
                         "Installed" if deps_installed else "Run: cd bridge && npm install")
        
    def check_flutter(self):
        """Check Flutter environment"""
        self.print_header("Flutter Environment")
        
        # Flutter Version
        flutter_ok, flutter_output = self.run_command(['flutter', '--version'])
        self.results['flutter']['installed'] = flutter_ok
        
        if flutter_ok:
            # Parse version
            lines = flutter_output.split('\n')
            version_line = [l for l in lines if 'Flutter' in l][0] if lines else ""
            self.print_status("Flutter", True, version_line.strip())
            
            # Run flutter doctor
            print("\nRunning Flutter Doctor:")
            doctor_ok, doctor_output = self.run_command(['flutter', 'doctor', '-v'])
            
            # Parse doctor output for issues
            if doctor_ok:
                issues = []
                for line in doctor_output.split('\n'):
                    if '✗' in line or '!' in line:
                        issues.append(line.strip())
                    elif '✓' in line:
                        component = line.split('✓')[1].strip()
                        self.print_status(f"  {component[:30]}", True)
                
                if issues:
                    print("\nFlutter Doctor Issues:")
                    for issue in issues:
                        self.print_warning(issue)
        else:
            self.print_status("Flutter", False, "Not installed")
            self.errors.append("Flutter not found. Install from https://flutter.dev")
    
    def check_android(self):
        """Check Android development environment"""
        self.print_header("Android Development")
        
        # Android SDK
        android_home = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
        self.results['android']['sdk_path'] = android_home
        
        if android_home and os.path.exists(android_home):
            self.print_status("Android SDK", True, android_home)
            
            # Check for key SDK components
            sdk_manager = Path(android_home) / 'cmdline-tools/latest/bin/sdkmanager'
            if not sdk_manager.exists():
                sdk_manager = Path(android_home) / 'tools/bin/sdkmanager'
            
            if sdk_manager.exists():
                self.print_status("  SDK Manager", True)
            else:
                self.print_warning("  SDK Manager not found in expected location")
        else:
            self.print_status("Android SDK", False, "ANDROID_HOME not set")
            self.errors.append("Set ANDROID_HOME environment variable")
        
        # Check ADB
        adb_ok, adb_version = self.run_command(['adb', 'version'])
        self.results['android']['adb'] = adb_ok
        self.print_status("ADB", adb_ok, 
                         adb_version.split('\n')[0] if adb_ok else "Not found")
        
        # Java/JDK
        java_ok, java_version = self.run_command(['java', '-version'])
        self.results['android']['java'] = java_ok
        self.print_status("Java", java_ok, "Installed" if java_ok else "Not found")
        
    def check_configuration(self):
        """Check configuration files"""
        self.print_header("Configuration Files")
        
        configs = {
            'bridge/.env': 'Bridge Server Config',
            'ml/.env': 'ML Engine Config',
            'android/key.properties': 'Android Keystore Config',
            'broker-catalogs/catalogs/brokers.json': 'Broker Catalog'
        }
        
        for filepath, name in configs.items():
            exists = Path(filepath).exists()
            self.results['configuration'][filepath] = exists
            
            if exists:
                self.print_status(name, True, "Found")
            else:
                template = f"{filepath}.template"
                if Path(template).exists():
                    self.print_status(name, False, f"Missing (template available)")
                    self.print_warning(f"  Create from template: cp {template} {filepath}")
                else:
                    self.print_status(name, False, "Missing")
                    
    def check_connectivity(self):
        """Check network connectivity"""
        self.print_header("Network Connectivity")
        
        # Check localhost ports
        import socket
        
        ports_to_check = {
            8080: "Bridge Server",
            8081: "ML Metrics",
            443: "MT4/MT5"
        }
        
        for port, service in ports_to_check.items():
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            is_open = result == 0
            self.results['connectivity'][f'port_{port}'] = is_open
            self.print_status(f"Port {port} ({service})", 
                            True if port == 443 else is_open,
                            "Open" if is_open else "Closed (OK if not running)")
        
        # Check internet
        try:
            import urllib.request
            urllib.request.urlopen('https://www.google.com', timeout=5)
            self.results['connectivity']['internet'] = True
            self.print_status("Internet Connection", True)
        except:
            self.results['connectivity']['internet'] = False
            self.print_status("Internet Connection", False)
            self.errors.append("No internet connection")
    
    def check_gpu(self):
        """Check GPU availability for ML"""
        self.print_header("GPU/CUDA Support")
        
        try:
            import torch
            cuda_available = torch.cuda.is_available()
            self.results['gpu'] = {
                'cuda_available': cuda_available,
                'device_count': torch.cuda.device_count() if cuda_available else 0
            }
            
            if cuda_available:
                self.print_status("CUDA", True, 
                                f"{torch.cuda.device_count()} GPU(s) available")
                for i in range(torch.cuda.device_count()):
                    gpu_name = torch.cuda.get_device_name(i)
                    self.print_status(f"  GPU {i}", True, gpu_name)
            else:
                self.print_status("CUDA", False, "No CUDA GPUs available")
                self.print_warning("ML will run on CPU (slower)")
        except ImportError:
            self.print_warning("PyTorch not installed - can't check GPU")
            
    def generate_report(self):
        """Generate final report"""
        self.print_header("Validation Summary")
        
        # Count issues
        total_errors = len(self.errors)
        total_warnings = len(self.warnings)
        
        if total_errors == 0:
            print(f"\n{Colors.GREEN}{Colors.BOLD}✓ Environment is ready!{Colors.END}")
            print(f"  {Colors.GREEN}All critical checks passed{Colors.END}")
        else:
            print(f"\n{Colors.RED}{Colors.BOLD}✗ Environment has issues{Colors.END}")
            print(f"  {Colors.RED}{total_errors} error(s) found{Colors.END}")
            
        if total_warnings > 0:
            print(f"  {Colors.YELLOW}{total_warnings} warning(s) found{Colors.END}")
        
        # Save detailed report
        report_path = Path('environment_report.json')
        with open(report_path, 'w') as f:
            json.dump({
                'results': self.results,
                'warnings': self.warnings,
                'errors': self.errors,
                'summary': {
                    'ready': total_errors == 0,
                    'error_count': total_errors,
                    'warning_count': total_warnings
                }
            }, f, indent=2)
        
        print(f"\nDetailed report saved to: {report_path}")
        
        # Next steps
        if total_errors > 0:
            print(f"\n{Colors.BOLD}Next Steps:{Colors.END}")
            print("1. Fix the errors listed above")
            print("2. Run this validator again")
            print("3. Once all checks pass, run: ./setup_environment.sh")
        else:
            print(f"\n{Colors.BOLD}Next Steps:{Colors.END}")
            print("1. Review any warnings above")
            print("2. Run: ./setup_environment.sh")
            print("3. Configure your MT4/MT5 demo credentials")
            print("4. Start the system: ./start_system.sh")
            
    def run(self):
        """Run all validation checks"""
        print(f"{Colors.BLUE}{Colors.BOLD}")
        print("╔═══════════════════════════════════════════════════════╗")
        print("║        QuantumTrader-Pro Environment Validator        ║")
        print("╚═══════════════════════════════════════════════════════╝")
        print(f"{Colors.END}")
        
        # Run all checks
        self.check_system()
        self.check_python()
        self.check_node()
        self.check_flutter()
        self.check_android()
        self.check_configuration()
        self.check_connectivity()
        self.check_gpu()
        
        # Generate report
        self.generate_report()
        
        return len(self.errors) == 0

if __name__ == "__main__":
    validator = EnvironmentValidator()
    success = validator.run()
    sys.exit(0 if success else 1)