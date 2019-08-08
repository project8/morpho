#!/bin/bash

pip install pystan==2.19.0

cd IO && python IO_test.py && cd ..
cd misc && python misc_test.py && cd ..
cd sampling && python sampling_test.py && cd ..