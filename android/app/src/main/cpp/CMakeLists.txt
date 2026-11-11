# LAME 4.0 (lame.sourceforge.io, LGPL), unmodified, for the click track's MP3
# export: its own shared library, loaded by lib/src/audio/mp3_encoder.dart.
# Only the encoder: mpglib_interface.c (decoding) and the x86 asm are left out.
cmake_minimum_required(VERSION 3.18)
project(mp3lame C)

file(GLOB LAME_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/lame/*.c)
add_library(mp3lame SHARED ${LAME_SOURCES})
target_include_directories(mp3lame PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/lame)
target_compile_definitions(mp3lame PRIVATE
  STDC_HEADERS HAVE_STDINT_H HAVE_INTTYPES_H HAVE_ERRNO_H HAVE_FCNTL_H
  ieee754_float32_t=float)
target_compile_options(mp3lame PRIVATE -O2 -w)
target_link_libraries(mp3lame m)
# 16 KB pages (Android 15+).
target_link_options(mp3lame PRIVATE -Wl,-z,max-page-size=16384)
