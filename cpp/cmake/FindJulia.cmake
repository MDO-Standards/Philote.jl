# FindJulia.cmake - Find Julia installation
#
# This module finds the Julia installation and provides:
#   JULIA_EXECUTABLE - Path to julia executable
#   JULIA_INCLUDE_DIRS - Include directories for Julia headers
#   JULIA_LIBRARY - Path to Julia library
#   JULIA_VERSION_STRING - Julia version string
#
# Usage:
#   find_package(Julia REQUIRED)

# Find Julia executable
find_program(JULIA_EXECUTABLE julia
    DOC "Julia executable"
    HINTS
        ENV JULIA_DIR
        ENV JULIA_BINDIR
    PATHS
        /usr/bin
        /usr/local/bin
        /opt/julia/bin
        $ENV{HOME}/.julia/bin
)

if(JULIA_EXECUTABLE)
    # Get Julia version
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} --version
        OUTPUT_VARIABLE JULIA_VERSION_RAW
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    # Extract version number
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" JULIA_VERSION_STRING "${JULIA_VERSION_RAW}")

    # Get Julia include directory
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} -E "joinpath(Sys.BINDIR, Base.INCLUDEDIR, \"julia\")"
        OUTPUT_VARIABLE JULIA_INCLUDE_DIRS_RAW
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    # Remove quotes from output
    string(REPLACE "\"" "" JULIA_INCLUDE_DIRS "${JULIA_INCLUDE_DIRS_RAW}")

    # Get Julia library directory
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} -E "joinpath(Sys.BINDIR, Base.LIBDIR)"
        OUTPUT_VARIABLE JULIA_LIBRARY_DIR_RAW
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    # Remove quotes from output
    string(REPLACE "\"" "" JULIA_LIBRARY_DIR "${JULIA_LIBRARY_DIR_RAW}")

    # Find the Julia library
    if(APPLE)
        set(JULIA_LIB_NAMES julia libjulia libjulia.dylib)
    elseif(UNIX)
        set(JULIA_LIB_NAMES julia libjulia libjulia.so)
    elseif(WIN32)
        set(JULIA_LIB_NAMES julia libjulia.dll libjulia.lib)
    else()
        set(JULIA_LIB_NAMES julia libjulia)
    endif()

    find_library(JULIA_LIBRARY
        NAMES ${JULIA_LIB_NAMES}
        PATHS ${JULIA_LIBRARY_DIR}
        PATH_SUFFIXES lib
        NO_DEFAULT_PATH
    )

    # Also search system paths if not found
    if(NOT JULIA_LIBRARY)
        find_library(JULIA_LIBRARY
            NAMES ${JULIA_LIB_NAMES}
        )
    endif()

    # Verify include directory exists
    if(NOT EXISTS "${JULIA_INCLUDE_DIRS}")
        message(WARNING "Julia include directory does not exist: ${JULIA_INCLUDE_DIRS}")
        set(JULIA_INCLUDE_DIRS "")
    endif()

endif()

# Handle the QUIETLY and REQUIRED arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Julia
    REQUIRED_VARS JULIA_EXECUTABLE JULIA_LIBRARY JULIA_INCLUDE_DIRS
    VERSION_VAR JULIA_VERSION_STRING
    FAIL_MESSAGE "Could not find Julia. Please ensure Julia is installed and in your PATH."
)

mark_as_advanced(
    JULIA_EXECUTABLE
    JULIA_INCLUDE_DIRS
    JULIA_LIBRARY
    JULIA_VERSION_STRING
)

# Print found information
if(Julia_FOUND AND NOT Julia_FIND_QUIETLY)
    message(STATUS "Found Julia ${JULIA_VERSION_STRING}")
    message(STATUS "  Executable: ${JULIA_EXECUTABLE}")
    message(STATUS "  Include dirs: ${JULIA_INCLUDE_DIRS}")
    message(STATUS "  Library: ${JULIA_LIBRARY}")
endif()
