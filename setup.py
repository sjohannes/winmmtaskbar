#!/usr/bin/env python

from setuptools import setup

try:
    from Cython.Build import cythonize
except ImportError:
    import ast, re
    from setuptools import Extension
    meta_re = re.compile(
        r'BEGIN: Cython Metadata\s(.*?)\sEND: Cython Metadata',
        re.S)
    def cythonize(source):
        """Fake cythonize() that barely works for our case when the .pyx file
        has been pre-translated to .cpp
        """
        assert source.endswith('.pyx')
        name = source[:-4]
        with open(name + '.cpp') as f:
            text = f.read()
        # Read distutils metadata (required libraries etc.)
        meta = meta_re.search(text).group(1)
        meta = ast.literal_eval(meta)
        meta = meta['distutils']
        ext = Extension(name, [name + '.cpp'], **meta)
        return [ext]

setup(
    name='winmmtaskbar',
    version='1.0.0.dev',
    author='Johannes Sasongko',
    author_email='sasongko@gmail.com',
    url='https://github.com/exaile/winmmtaskbar',
    description='Windows 7+ taskbar thumb buttons for multimedia apps',
    long_description='winmmtaskbar adds Previous, Play/Pause, and Next buttons'
        ' to the taskbar thumbnail of a window in Windows 7 and later.',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Environment :: Win32 (MS Windows)',
        'Intended Audience :: Developers',
        'License :: OSI Approved',
        'Operating System :: Microsoft :: Windows',
        'Programming Language :: Cython',
        'Topic :: Multimedia :: Sound/Audio',
        'Topic :: Multimedia :: Video',
    ],
    license='LGPLv2.1+',
    ext_modules=cythonize('winmmtaskbar.pyx'),
)

# vi: et sts=4 sw=4 ts=4 tw=79
