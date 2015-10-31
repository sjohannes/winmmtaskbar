#!/usr/bin/env python

from setuptools import setup, Extension
from Cython.Build import cythonize

extensions = [
    Extension('winmmtaskbar', ['winmmtaskbar.pyx'])
]

setup(
    name='winmmtaskbar',
    version='1.0.0',
    ext_modules=cythonize(extensions),
)

# vi: et sts=4 sw=4 ts=4 tw=80
