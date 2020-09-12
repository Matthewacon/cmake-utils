cmake_minimum_required(VERSION 3.8)

set(_BOOTSTRAP_FILE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake-bootstrap.cmake")

function(propagate_cli_arguments)
 cmake_parse_arguments(
  prop
  ""
  "RESULT_VAR"
  "BUILD_VARIABLES"
  ${ARGN}
 )

 #Ensure result parameter was provided
 if(NOT DEFINED prop_RESULT_VAR OR NOT DEFINED prop_BUILD_VARIABLES)
  message(
   FATAL_ERROR 
   "'propogate_cli_arguments' accepts the following named arguments:\
   \n(REQUIRED) 'RESULT_VAR' - The variable to store the parsed parameters in\
   \n(REQUIRED) 'BUILD_VARIABLES' - The list of arguments to separate CLI arguments from\
  ")
 endif()

 #Assemble argument string
 list(SORT prop_BUILD_VARIABLES)

 foreach(VAR_NAME ${prop_BUILD_VARIABLES})
  if(NOT "${${VAR_NAME}}" STREQUAL "" AND NOT "${VAR_NAME}" MATCHES "^_BOOTSTRAP_")
   #All CLI specified build flags will have the property `HELPSTRING="No help, variable specified on the command line."`
   get_property(help_string CACHE "${VAR_NAME}" PROPERTY HELPSTRING)
   if("${help_string}" MATCHES "(No help, variable specified on the command line.)")
    set(result ${result} "-D${VAR_NAME}=${${VAR_NAME}}")
   endif()
  endif()
 endforeach()
 set("${prop_RESULT_VAR}" "${result}" PARENT_SCOPE)
endfunction()

function(bootstrap_build)
 cmake_parse_arguments(
  bb
  ""
  "BOOTSTRAP_NAME;BUILD_CMAKE_ROOT;TARGET_NAME;GENERATOR;BUILD_COMMAND"
  "ENVIRONMENT;EXTRA_CMAKE_FLAGS"
  ${ARGN}
 )

 if(NOT DEFINED bb_BOOTSTRAP_NAME OR NOT DEFINED bb_BUILD_CMAKE_ROOT)
  message(
   FATAL_ERROR 
   "'bootstrap_build' accepts the following named arguments:\
   \n(REQUIRED) 'BOOTSTRAP_NAME' - The name of the bootstrapped project\
   \n(REQUIRED) 'BUILD_CMAKE_ROOT' - The directory containing the 'CMakeLists.txt' of the bootstrapped project\
   \n(OPTIONAL) 'TARGET_NAME' - Common target name for bootstrap build tasks (will add targets \"\${TARGET_NAME}_configure\" and \"\${TARGET_NAME}_build\"), defaults to '\${BOOTSTRAP_NAME}'\
   \n(OPTIONAL) 'GENERATOR' - The CMake generator to use for the bootstrapped project, defaults to 'Ninja'\
   \n(OPTIONAL) 'BUILD_COMMAND' - The build command to use for the bootstrapped project, defaults to the generator's build command\
   \n(OPTIONAL) 'ENVIRONMENT' - A list of environment variables [VAR1=1 VAR2=2 ...] to use for the bootstrapped configure and build tasks\
   \n(OPTIONAL) 'EXTRA_CMAKE_FLAGS' - A list of CMake flags [FLAG1=1 FLAG2=2 ...] to set when configuring the bootstrapped project\
  ")
 endif()
 
 #If the path is relative, use the top-level CMakeLists.txt dir as the root 
 if(NOT "${bb_BUILD_CMAKE_ROOT}" MATCHES "^\/")
  set(bb_BUILD_CMAKE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/${bb_BUILD_CMAKE_ROOT}")
 endif()
 message(STATUS "Using CMakeLists.txt from: ${bb_BUILD_CMAKE_ROOT}")

 #Use default target name if none is specified
 if(NOT DEFINED bb_TARGET_NAME)
  set(bb_TARGET_NAME "${bb_BOOTSTRAP_NAME}")
 endif()

 #Use ninja as the default generator is none is specified
 if(NOT DEFINED bb_GENERATOR)
  message(STATUS "Build generator not specified, defaulting to ninja")
  set(bb_GENERATOR Ninja)
  find_program(generator_found ninja)
 else()
  find_program(generator_found "${bb_GENERATOR}") 
 endif()

 if("${generator_found}" STREQUAL "generator_found-NOTFOUND")
  message(FATAL_ERROR "The generator '${bb_GENERATOR}' could not be found")
 endif()

 #Use generator as the default build command if none is specified
 if(NOT DEFINED bb_BUILD_COMMAND)
  set(bb_BUILD_COMMAND "${generator_found}")
 endif()

 #If an environment was set, it needs to be converted from a list to a string
 if(DEFINED bb_ENVIRONMENT)
  foreach(env_pair ${bb_ENVIRONMENT})
   set(unpacked_env ${unpacked_env} ${env_pair})
  endforeach()
 endif()

 #Parse all extra cmake flags
 if(DEFINED bb_EXTRA_CMAKE_FLAGS)
  foreach(flag ${bb_EXTRA_CMAKE_FLAGS})
   set(unpacked_cmake_flags ${unpacked_cmake_flags} "-D${flag}")
  endforeach()
 endif()
 
 #Get CLI arguments to pass to bootstrapped build 
 get_cmake_property(invocation_args VARIABLES)
 propagate_cli_arguments(RESULT_VAR args_to_propagate BUILD_VARIABLES ${invocation_args})
 foreach(flag ${args_to_propagate})
  set(unpacked_cmake_flags ${unpacked_cmake_flags} ${flag})
 endforeach()
 
 #Directory for bootstrapped build (directory created in script mode, see bottom of file) 
 set(bootstrap_build_dir "${PROJECT_BINARY_DIR}/${bb_BOOTSTRAP_NAME}")

 #Build stage markers
 set(bootstrap_clean_output "virtual_clean_output")
 set(bootstrap_configure_output "${PROJECT_BINARY_DIR}/${bb_BOOTSTRAP_NAME}_configured.txt")
 set(bootstrap_build_output "${PROJECT_BINARY_DIR}/${bb_BOOTSTRAP_NAME}_built.txt")

 #Copy this file to the build directory for usage in script mode (see bottom of file)
 set(bootstrap_script_path "${PROJECT_BINARY_DIR}/cmake-bootstrap.cmake")
 if(NOT EXISTS "${bootstrap_script_path}") 
  file(COPY "${_BOOTSTRAP_FILE_PATH}" DESTINATION "${PROJECT_BINARY_DIR}")
 endif()

 #Add custom command to deal with stale project builds
 add_custom_command(
  OUTPUT "Clean up stale artifacts"
  OUTPUT "${bootstrap_clean_output}"
  COMMAND ${CMAKE_COMMAND} -D_BOOTSTRAP_SCRIPT_MODE="ON" -D_BOOTSTRAP_SCRIPT_BUILD_DIR="${PROJECT_BINARY_DIR}" -D_BOOTSTRAP_SCRIPT_TARGET_NAME="${bb_TARGET_NAME}" -D_BOOTSTRAP_SCRIPT_PROJECT_NAME="${bb_BOOTSTRAP_NAME}" -P "${bootstrap_script_path}"
 )
 add_custom_target(
  "${bb_TARGET_NAME}_clean" ALL
  DEPENDS "${bootstrap_clean_output}"
 )

 #Add custom command to bootstrap configure of dependent project
 add_custom_command(
  OUTPUT "Configure bootstrapped project"
  OUTPUT "${bootstrap_configure_output}"
  COMMAND ${CMAKE_COMMAND} -E env ${unpacked_env} ${CMAKE_COMMAND} "-G${bb_GENERATOR}" ${bb_BUILD_CMAKE_ROOT} ${unpacked_cmake_flags} 
  COMMAND ${CMAKE_COMMAND} -E touch "${bootstrap_configure_output}"
  WORKING_DIRECTORY "${bootstrap_build_dir}"
  DEPENDS "${bb_TARGET_NAME}_clean" 
 )
 add_custom_target(
  "${bb_TARGET_NAME}_configure" ALL
  DEPENDS "${bootstrap_configure_output}"
 )

 #Add custom command to bootstrap build dependent project 
 add_custom_command(
  OUTPUT "Build bootstrapped project"
  OUTPUT "${bootstrap_build_output}"
  COMMAND ${CMAKE_COMMAND} -E env ${unpacked_env} "${bb_BUILD_COMMAND}"
  COMMAND ${CMAKE_COMMAND} -E touch "${bootstrap_build_output}"
  WORKING_DIRECTORY "${bootstrap_build_dir}"
  DEPENDS "${bb_TARGET_NAME}_configure"
 )
 add_custom_target(
  "${bb_TARGET_NAME}_build" ALL
  DEPENDS "${bootstrap_build_output}" 
 )
endfunction()

#Script mode
#Cleans up stale build artifacts
if(DEFINED _BOOTSTRAP_SCRIPT_MODE)
 if(NOT DEFINED _BOOTSTRAP_SCRIPT_BUILD_DIR
    OR NOT DEFINED _BOOTSTRAP_SCRIPT_PROJECT_NAME
    OR NOT DEFINED _BOOTSTRAP_SCRIPT_TARGET_NAME)
  message(
   FATAL_ERROR
   "cmake-bootstrap.cmake in script mode accepts the following named arguments:\
   \n(REQUIRED) '_BOOTSTRAP_SCRIPT_BUILD_DIR' - The directory top level project invoking bootstrapped builds\
   \n(REQUIRED) '_BOOTSTRAP_SCRIPT_PROJECT_NAME' - The name of the bootstrapped project\
   \n(REQUIRED) '_BOOTSTRAP_SCRIPT_TARGET_NAME' - The target name prefix for the bootstrapped project\
  ")
 endif()

 set(bootstrapped_build_dir "${_BOOTSTRAP_SCRIPT_BUILD_DIR}/${_BOOTSTRAP_SCRIPT_PROJECT_NAME}")

 #Clean up bootstrapped build directory if the configure stage marker is missing
 if(NOT EXISTS "${_BOOTSTRAP_SCRIPT_BUILD_DIR}/${_BOOTSTRAP_SCRIPT_TARGET_NAME}_configure.txt")
  if(EXISTS "${bootstrapped_build_dir}")
   message(STATUS "Cleaning stale build directory for bootstrapped project: '${_BOOTSTRAP_SCRIPT_PROJECT_NAME}'")
   file(REMOVE_RECURSE "${bootstrapped_build_dir}")
  endif()
 endif()

 #Create bootstrap build directory if it doesn't already exist
 if(NOT EXISTS "${bootstrapped_build_dir}")
  file(MAKE_DIRECTORY "${bootstrapped_build_dir}") 
 endif()
endif()
