#!/usr/bin/env nu

glob "./textures/*.png" | optipng -o7 -zm1-9 -nc -strip all -clobber ...$in
