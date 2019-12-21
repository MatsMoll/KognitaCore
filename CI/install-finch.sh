#!/usr/bin/env bash

git clone https://github.com/namolnad/Finch.git
cd Finch
make install
cd ..
rm -rf Finch
