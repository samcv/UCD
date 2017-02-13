#!/usr/bin/env sh
pod-render.pl6 --md UCD-gen.p6
PERL6LIB=lib pod-render.pl6 --md lib/UCDlib.pm6

mv UCD-gen.md docs
mv UCDlib.md docs
