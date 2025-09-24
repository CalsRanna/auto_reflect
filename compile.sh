#!/bin/bash

set -e

mkdir -p build
dart compile exe bin/auto_reflect.dart -o build/journal