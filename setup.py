from __future__ import print_function

import platform
import os
import sys
from glob import glob
from multiprocessing import cpu_count

from _setup_libssh2 import build_ssh2

import versioneer
from setuptools import setup, find_packages

cpython = platform.python_implementation() == 'CPython'

try:
    from Cython.Distutils.extension import Extension
    from Cython.Distutils import build_ext
except ImportError:
    from setuptools import Extension
    USING_CYTHON = False
else:
    USING_CYTHON = True

ON_RTD = os.environ.get('READTHEDOCS') == 'True'

REDLIBSSH2_BUILD_TRACING = bool(os.environ.get('REDLIBSSH2_BUILD_TRACING', 0))
SYSTEM_BUILD_MINGW = bool(os.environ.get('SYSTEM_BUILD_MINGW', 0))
SYSTEM_LIBSSH2 = bool(os.environ.get('SYSTEM_LIBSSH2', 0)) or ON_RTD

ON_WINDOWS = platform.system() == 'Windows' or SYSTEM_BUILD_MINGW==True
ON_LINUX = platform.system() == 'Linux'
ON_OSX = platform.system() == 'Darwin'

# Only build libssh if running a build
if not SYSTEM_LIBSSH2 and not ON_OSX and (len(sys.argv) >= 2 and not (
        '--help' in sys.argv[1:] or
        sys.argv[1] in (
            '--help-commands', 'egg_info', '--version', 'clean',
            'sdist', '--long-description')) and
        __name__ == '__main__'):
    build_ssh2()

ext = 'pyx' if USING_CYTHON else 'c'
sources = glob('ssh2/*.%s' % (ext,))
_arch = platform.architecture()[0][0:2]
_libs = ['ssh2'] if not ON_WINDOWS else [
    'Ws2_32', 'libssh2', 'user32',
    'libcrypto%sMD' % _arch, 'libssl%sMD' % _arch,
    'zlibstatic',
]

# _comp_args = ["-ggdb"]
_fwd_default = 0
_comp_args = ["-O3"] if not ON_WINDOWS else None
_have_agent_fwd = bool(int(os.environ.get('HAVE_AGENT_FWD', _fwd_default)))

cython_directives = {
    'language_level': '3',
    'embedsignature': True,
    'boundscheck': False,
    'optimize.use_switch': True,
    'wraparound': False
}
cython_args = {}

if USING_CYTHON:
    cython_args = {
        'cython_directives': cython_directives,
        'cython_compile_time_env': {
            'HAVE_AGENT_FWD': _have_agent_fwd,
            'HAVE_POLL': ON_LINUX,
        }
    }
    if REDLIBSSH2_BUILD_TRACING==True:
        cython_args.update({'define_macros':[("CYTHON_TRACE", 1),("CYTHON_TRACE_NOGIL", 1)]})
        cython_args['cython_directives'].update({'linetrace':True})
    sys.stdout.write("Cython arguments: %s%s" % (cython_args, os.linesep))


runtime_library_dirs = ["$ORIGIN/."] if not SYSTEM_LIBSSH2 or ON_OSX else None
_lib_dir = os.path.abspath("./src/src") if not SYSTEM_LIBSSH2 or ON_OSX else "/usr/local/lib"
include_dirs = ["libssh2/include"] if ON_RTD or not SYSTEM_LIBSSH2 or ON_OSX else ["/usr/local/include"]

extensions = [
    Extension(sources[i].split('.')[0].replace(os.path.sep, '.'),
              sources=[sources[i]],
              include_dirs=include_dirs,
              libraries=_libs,
              library_dirs=[_lib_dir,os.path.abspath("./src/src")],
              # runtime_library_dirs=runtime_library_dirs,
              extra_compile_args=_comp_args,
              **cython_args
    )
    for i in range(len(sources))]

package_data = {'ssh2': ['*.pxd', 'libssh2.so*']}

if ON_WINDOWS:
    package_data['ssh2'].extend([
        'libcrypto*.dll', 'libssl*.dll', 'libssh2.dll'
    ])

cmdclass = versioneer.get_cmdclass()
if USING_CYTHON:
    cmdclass['build_ext'] = build_ext

install_requires = []

test_deps = [
    'coveralls',
    'pytest-cov',
    'pylint',
    'bandit',
    'safety'
]

setup(
    name='redlibssh2',
    version=versioneer.get_version(),
    cmdclass=cmdclass,
    url='https://github.com/Red-M/Redlibssh2',
    license='LGPLv2',
    author='Red_M',
    author_email='redlibssh2_pypi@red-m.net',
    description=('Alternate bindings for libssh2 C library'),
    long_description=open('README.rst').read(),
    packages=find_packages(
        '.', exclude=('embedded_server', 'embedded_server.*',
                      'tests', 'tests.*',
                      '*.tests', '*.tests.*')),
    zip_safe=False,
    include_package_data=True,
    platforms='any',
    install_requires=install_requires,
    extras_require={
        'tests':list(set(install_requires+test_deps))
    },
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'License :: OSI Approved :: GNU Lesser General Public License v2 (LGPLv2)',
        'Intended Audience :: Developers',
        'Operating System :: OS Independent',
        'Programming Language :: C',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Topic :: System :: Shells',
        'Topic :: System :: Networking',
        'Topic :: Software Development :: Libraries',
        'Topic :: Software Development :: Libraries :: Python Modules',
        'Operating System :: POSIX',
        'Operating System :: POSIX :: Linux',
        'Operating System :: POSIX :: BSD',
        # 'Operating System :: Microsoft :: Windows',
        'Operating System :: MacOS :: MacOS X',
    ],
    ext_modules=extensions,
    package_data=package_data,
)
