cmake_minimum_required(VERSION 3.15)
project(voice_pop_runtime LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT EMSCRIPTEN)
  message(FATAL_ERROR "Build with the Emscripten toolchain")
endif()
if(NOT SHERPA_SOURCE_DIR)
  message(FATAL_ERROR "SHERPA_SOURCE_DIR must name the pinned sherpa-onnx source")
endif()
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SHERPA_ONNX_ENABLE_WASM ON CACHE BOOL "" FORCE)
set(SHERPA_ONNX_ENABLE_C_API ON CACHE BOOL "" FORCE)
foreach(feature PYTHON TESTS CHECK PORTAUDIO JNI TTS WEBSOCKET GPU BINARY SPEAKER_DIARIZATION)
  set(SHERPA_ONNX_ENABLE_${feature} OFF CACHE BOOL "" FORCE)
endforeach()
set(SHERPA_ONNX_BUILD_C_API_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SHERPA_ONNX_LINK_LIBSTDCPP_STATICALLY OFF CACHE BOOL "" FORCE)
set(SHERPA_ONNX_USE_PRE_INSTALLED_ONNXRUNTIME_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
add_compile_options(-msimd128)
add_subdirectory("${SHERPA_SOURCE_DIR}" sherpa)
add_executable(voice-pop-runtime voice-pop-runtime.cc)
target_link_libraries(voice-pop-runtime PRIVATE sherpa-onnx-c-api)
target_link_options(voice-pop-runtime PRIVATE
  --no-entry
  -msimd128
  "-sMODULARIZE=1"
  "-sEXPORT_NAME=VoicePopSherpa"
  "-sENVIRONMENT=web,worker,node"
  "-sFORCE_FILESYSTEM=1"
  "-sALLOW_MEMORY_GROWTH=1"
  "-sINITIAL_MEMORY=134217728"
  "-sMAXIMUM_MEMORY=1073741824"
  "-sSTACK_SIZE=10485760"
  "-sEXPORTED_FUNCTIONS=['_malloc','_free']"
  "-sEXPORTED_RUNTIME_METHODS=['FS','UTF8ToString','HEAPF32']"
)
set_target_properties(voice-pop-runtime PROPERTIES SUFFIX ".js")
