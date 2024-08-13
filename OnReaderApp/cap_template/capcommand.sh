#!/bin/bash
rm -rf cap/config/*
chmod 755 cap/start
chmod 755 cap/OnReaderApp
chmod 755 cap/*.so
chmod 755 cap/*.a
chmod 755 cap/*.dll
../cap_gen.sh -d cap_description.in -o onreaderapp_cap.upgx
