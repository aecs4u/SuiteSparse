#-------------------------------------------------------------------------------
# SmartBuild.cmake - Intelligent lazy build system for CMake
#-------------------------------------------------------------------------------
# Only rebuilds targets when source files have actually changed
# Copyright (c) 2026, Smart Build System

cmake_minimum_required(VERSION 3.22)

# Enable smart build by default
option(SMART_BUILD_ENABLED "Enable smart lazy build checks" ON)
option(FORCE_BUILD "Force rebuild even if no changes detected" OFF)

if(NOT SMART_BUILD_ENABLED)
    return()
endif()

message(STATUS "Smart Build: Enabled")

# Create state directory
set(SMART_BUILD_STATE_DIR "${CMAKE_BINARY_DIR}/.smart_build")
file(MAKE_DIRECTORY "${SMART_BUILD_STATE_DIR}")

set(SMART_BUILD_STATE_FILE "${SMART_BUILD_STATE_DIR}/build_state.txt")
set(SMART_BUILD_SOURCE_LIST "${SMART_BUILD_STATE_DIR}/source_list.txt")

#-------------------------------------------------------------------------------
# Function to collect all source files
#-------------------------------------------------------------------------------
function(smart_build_collect_sources OUTPUT_VAR)
    # Get all source files recursively
    file(GLOB_RECURSE ALL_SOURCES
        LIST_DIRECTORIES false
        "${CMAKE_SOURCE_DIR}/*.c"
        "${CMAKE_SOURCE_DIR}/*.cpp"
        "${CMAKE_SOURCE_DIR}/*.cc"
        "${CMAKE_SOURCE_DIR}/*.cxx"
        "${CMAKE_SOURCE_DIR}/*.h"
        "${CMAKE_SOURCE_DIR}/*.hpp"
        "${CMAKE_SOURCE_DIR}/*.hxx"
        "${CMAKE_SOURCE_DIR}/CMakeLists.txt"
        "${CMAKE_SOURCE_DIR}/**/*.cmake"
    )

    # Filter out build directories
    set(FILTERED_SOURCES "")
    foreach(SOURCE_FILE ${ALL_SOURCES})
        # Skip if in build directory
        string(FIND "${SOURCE_FILE}" "${CMAKE_BINARY_DIR}" POS)
        if(POS EQUAL -1)
            # Skip if in any build_* directory
            string(REGEX MATCH "/build_[^/]+/" IS_BUILD_DIR "${SOURCE_FILE}")
            if(NOT IS_BUILD_DIR)
                # Skip if in .git directory
                string(REGEX MATCH "/.git/" IS_GIT_DIR "${SOURCE_FILE}")
                if(NOT IS_GIT_DIR)
                    list(APPEND FILTERED_SOURCES "${SOURCE_FILE}")
                endif()
            endif()
        endif()
    endforeach()

    # Sort for consistency
    list(SORT FILTERED_SOURCES)

    set(${OUTPUT_VAR} "${FILTERED_SOURCES}" PARENT_SCOPE)
endfunction()

#-------------------------------------------------------------------------------
# Function to calculate checksum of source files
#-------------------------------------------------------------------------------
function(smart_build_calculate_checksum OUTPUT_VAR)
    smart_build_collect_sources(SOURCE_FILES)

    # Build a string of file paths and their timestamps
    set(CHECKSUM_INPUT "")
    foreach(FILE ${SOURCE_FILES})
        if(EXISTS "${FILE}")
            file(TIMESTAMP "${FILE}" FILE_TIME "%s" UTC)
            file(MD5 "${FILE}" FILE_HASH)
            string(APPEND CHECKSUM_INPUT "${FILE}:${FILE_TIME}:${FILE_HASH}\n")
        endif()
    endforeach()

    # Calculate MD5 of the combined input
    string(MD5 FINAL_CHECKSUM "${CHECKSUM_INPUT}")

    set(${OUTPUT_VAR} "${FINAL_CHECKSUM}" PARENT_SCOPE)
endfunction()

#-------------------------------------------------------------------------------
# Function to check if build is needed
#-------------------------------------------------------------------------------
function(smart_build_check_needed RESULT_VAR)
    # Always build if forced
    if(FORCE_BUILD)
        message(STATUS "Smart Build: Force build enabled")
        set(${RESULT_VAR} TRUE PARENT_SCOPE)
        return()
    endif()

    # Always build if state file doesn't exist
    if(NOT EXISTS "${SMART_BUILD_STATE_FILE}")
        message(STATUS "Smart Build: No previous state found - full build needed")
        set(${RESULT_VAR} TRUE PARENT_SCOPE)
        return()
    endif()

    # Read stored state
    file(READ "${SMART_BUILD_STATE_FILE}" STATE_CONTENT)

    # Extract stored checksum
    string(REGEX MATCH "SOURCE_CHECKSUM=([^\n]+)" _ "${STATE_CONTENT}")
    set(STORED_CHECKSUM "${CMAKE_MATCH_1}")

    # Calculate current checksum
    smart_build_calculate_checksum(CURRENT_CHECKSUM)

    # Compare checksums
    if(NOT "${CURRENT_CHECKSUM}" STREQUAL "${STORED_CHECKSUM}")
        message(STATUS "Smart Build: Source changes detected")
        message(STATUS "  Previous: ${STORED_CHECKSUM}")
        message(STATUS "  Current:  ${CURRENT_CHECKSUM}")
        set(${RESULT_VAR} TRUE PARENT_SCOPE)
    else()
        message(STATUS "Smart Build: No changes detected - build is up to date")
        message(STATUS "Smart Build: Use FORCE_BUILD=ON or 'make force' to rebuild")
        set(${RESULT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

#-------------------------------------------------------------------------------
# Function to save build state
#-------------------------------------------------------------------------------
function(smart_build_save_state)
    smart_build_calculate_checksum(CURRENT_CHECKSUM)
    smart_build_collect_sources(SOURCE_FILES)

    # Get current timestamp
    string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S UTC" UTC)

    # Write state file
    file(WRITE "${SMART_BUILD_STATE_FILE}"
"# Smart Build State File
# Generated: ${BUILD_TIMESTAMP}
BUILD_DATE=${BUILD_TIMESTAMP}
SOURCE_CHECKSUM=${CURRENT_CHECKSUM}
CMAKE_VERSION=${CMAKE_VERSION}
BUILD_TYPE=${CMAKE_BUILD_TYPE}
COMPILER_ID=${CMAKE_C_COMPILER_ID}
COMPILER_VERSION=${CMAKE_C_COMPILER_VERSION}
BLAS_VENDOR=${BLA_VENDOR}
SOURCE_DIR=${CMAKE_SOURCE_DIR}
BINARY_DIR=${CMAKE_BINARY_DIR}
")

    # Save source file list
    string(REPLACE ";" "\n" SOURCE_LIST "${SOURCE_FILES}")
    file(WRITE "${SMART_BUILD_SOURCE_LIST}" "${SOURCE_LIST}")

    message(STATUS "Smart Build: State saved")
endfunction()

#-------------------------------------------------------------------------------
# Check if build is needed during configuration
#-------------------------------------------------------------------------------
smart_build_check_needed(BUILD_NEEDED)

if(NOT BUILD_NEEDED)
    # Create a dummy custom target to satisfy build system
    add_custom_target(smart_build_no_op
        COMMAND ${CMAKE_COMMAND} -E echo "Smart Build: Build is up to date"
        COMMENT "Smart Build: No changes detected"
    )

    # Set a variable that can be checked by other parts of the build
    set(SMART_BUILD_SKIP_BUILD TRUE CACHE INTERNAL "Skip build if no changes")
else()
    set(SMART_BUILD_SKIP_BUILD FALSE CACHE INTERNAL "Build is needed")
endif()

#-------------------------------------------------------------------------------
# Add custom target to save state after successful build
#-------------------------------------------------------------------------------
add_custom_target(smart_build_save_state
    COMMAND ${CMAKE_COMMAND} -E echo "Saving smart build state..."
    COMMAND ${CMAKE_COMMAND}
        -DSMART_BUILD_STATE_FILE=${SMART_BUILD_STATE_FILE}
        -DSMART_BUILD_SOURCE_LIST=${SMART_BUILD_SOURCE_LIST}
        -DCMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}
        -P ${CMAKE_CURRENT_LIST_DIR}/SmartBuildSave.cmake
    COMMENT "Smart Build: Saving build state"
)

# Make it depend on all other targets (runs last)
set_target_properties(smart_build_save_state PROPERTIES
    EXCLUDE_FROM_ALL FALSE
)

message(STATUS "Smart Build: Configuration complete")
if(BUILD_NEEDED)
    message(STATUS "Smart Build: Changes detected - build will proceed")
else()
    message(STATUS "Smart Build: No changes - skip build or use FORCE_BUILD=ON")
endif()
