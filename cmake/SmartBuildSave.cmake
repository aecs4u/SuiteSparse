# SmartBuildSave.cmake - Helper script to save build state
# Called after successful build via custom target

cmake_minimum_required(VERSION 3.22)

# This script is executed with -P, so we need to use CMAKE_SCRIPT_MODE_FILE
if(NOT CMAKE_SCRIPT_MODE_FILE)
    message(FATAL_ERROR "This script must be run with cmake -P")
endif()

# Variables should be passed via -D flags
if(NOT DEFINED SMART_BUILD_STATE_FILE)
    message(FATAL_ERROR "SMART_BUILD_STATE_FILE not defined")
endif()

# Calculate checksum by re-reading source files
file(GLOB_RECURSE ALL_SOURCES
    LIST_DIRECTORIES false
    "${CMAKE_SOURCE_DIR}/*.c"
    "${CMAKE_SOURCE_DIR}/*.cpp"
    "${CMAKE_SOURCE_DIR}/*.h"
    "${CMAKE_SOURCE_DIR}/*.hpp"
)

set(CHECKSUM_INPUT "")
foreach(FILE ${ALL_SOURCES})
    if(EXISTS "${FILE}")
        file(TIMESTAMP "${FILE}" FILE_TIME "%s" UTC)
        file(MD5 "${FILE}" FILE_HASH)
        string(APPEND CHECKSUM_INPUT "${FILE}:${FILE_TIME}:${FILE_HASH}\n")
    endif()
endforeach()

string(MD5 CURRENT_CHECKSUM "${CHECKSUM_INPUT}")
string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S UTC" UTC)

# Update state file with current checksum
file(READ "${SMART_BUILD_STATE_FILE}" STATE_CONTENT)
string(REGEX REPLACE "SOURCE_CHECKSUM=[^\n]+" "SOURCE_CHECKSUM=${CURRENT_CHECKSUM}" STATE_CONTENT "${STATE_CONTENT}")
string(REGEX REPLACE "BUILD_DATE=[^\n]+" "BUILD_DATE=${BUILD_TIMESTAMP}" STATE_CONTENT "${STATE_CONTENT}")
file(WRITE "${SMART_BUILD_STATE_FILE}" "${STATE_CONTENT}")

message(STATUS "Smart Build state updated: ${CURRENT_CHECKSUM}")
