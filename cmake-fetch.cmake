cmake_minimum_required(VERSION 3.19)

include(FetchContent)

function(add_latent_dependency)
 #Parse and check arguments
 cmake_parse_arguments(
  adl
  ""
  "NAME;SCOPE_ID;SHALLOW"
  "TARGET_NAMES"
  ${ARGN}
 )
 if(NOT DEFINED adl_NAME)
  message(
   FATAL_ERROR
   "'add_latent_dependency' accepts the following named arguments:\
   \n(REQUIRED) 'NAME' - The designated name of the dependency to download\
   \n(OPTIONAL) 'TARGET_NAMES' - The names of the targets defined by the dependency, for linking later\
   \n(OPTIONAL) 'SCOPE_ID' - A unique scope prefix to destinguish invocations to all 'X_latent_dependency' functions\
   \n(OPTIONAL) 'SHALLOW' - Shallow clone dependency (default: 'FALSE')\
   \nThis function also accepts any arguments that FetchContent_Declare supports\
  ")
 endif()

 #Set up deps and targets variable names for global scope
 if(DEFINED adl_SCOPE_ID)
  set(deps_var "${adl_SCOPE_ID}_latent_dependencies")
  set(targets_var "${adl_SCOPE_ID}_latent_targets")
 else()
  set(deps_var "adl_latent_dependencies")
  set(targets_var "adl_latent_targets")
 endif()

 #Add name to latent dependency list
 list(APPEND "${deps_var}" "${adl_NAME}")
 set("${deps_var}" "${${deps_var}}" PARENT_SCOPE)

 #Add target to latent target list
 if(DEFINED adl_TARGET_NAMES)
  list(APPEND "${targets_var}" ${adl_TARGET_NAMES})
  set("${targets_var}" "${${targets_var}}" PARENT_SCOPE)
 endif()

 #Remove 'NAME' and 'TARGET_NAMES' named arguments from 'ARGV' so the rest
 #of the arguments can be propagated to 'FetchContent_Declare'
 #Note: There are multiple arguments for 'TARGET_NAMES' so they all have
 #to be removed as well
 list(FIND ARGV NAME index)
 list(REMOVE_AT ARGV ${index})
 list(REMOVE_AT ARGV ${index})
 list(FIND ARGV TARGET_NAMES index)
 list(REMOVE_AT ARGV ${index})
 foreach(target_element ${adl_TARGET_NAMES})
  list(REMOVE_AT ARGV ${index})
 endforeach()

 #Sanitize 'SHALLOW' argument
 if(DEFINED adl_SHALLOW)
  set(SHALLOW "${adl_SHALLOW}")
 else()
  set(SHALLOW FALSE)
 endif()

 #Invoke 'FetchContent_Declare', forwarding all 'ARGV' arguments
 FetchContent_Declare(
  ${adl_NAME}
  SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${adl_NAME}"
  BINARY_DIR "${CMAKE_BINARY_DIR}/dependencies/${adl_NAME}"
  GIT_SHALLOW ${SHALLOW}
  GIT_PROGRESS TRUE
  USES_TERMINAL_DOWNLOAD TRUE
  USES_TERMINAL_UPDATE TRUE
  ${ARGV}
 )
endfunction()

function(fetch_latent_dependencies)
 #Parse arguments
 cmake_parse_arguments(
  fld
  ""
  "SCOPE_ID;TARGETS_VAR;NO_FAIL"
  ""
  ${ARGN}
 )

 #Set up deps and targets name variables
 if(DEFINED fld_SCOPE_ID)
  message(STATUS "Fetching latent dependnecies for scope: ${fld_SCOPE_ID}")
  set(deps_var "${fld_SCOPE_ID}_latent_dependencies")
  set(targets_var "${fld_SCOPE_ID}_latent_targets")
 else()
  set(deps_var "adl_latent_dependencies")
  set(targets_var "adl_latent_targets")
 endif()

 #Set up switch for no fail
 if(NOT DEFINED fld_NO_FAIL)
  set(fld_NO_FAIL FALSE)
 endif()

 #Check that both the deps and targets variables are defined
 if(NOT DEFINED "${deps_var}")
  if(NOT ${fld_NO_FAIL})
   message(
    FATAL_ERROR
    "'fetch_latent_dependencies' invoked but '${deps_var}' is not defined!\
    \nIf you're using the 'SCOPE_ID' parameter when invoking 'add_latent_dependency', you must also specify it here.\
    \n\n'fetch_latent_dependencies' accepts the following named arguments:\
    \n(OPTIONAL) 'SCOPE_ID' - The same scope prefix used when invoking 'add_latent_dependency', if specified\
    \n(OPTIONAL) 'TARGETS_VAR' - The result variable for all targets\
    \n(OPTIONAL) 'NO_FAIL' - Do not throw an error when fetching if no dependencies have been defined (default: 'FALSE')\
   ")
  endif()
 else()
  #Set the 'TARGETS_VAR' if it was specified
  if(DEFINED fld_TARGETS_VAR)
   if(DEFINED "${targets_var}")
    set(targets_list "${${targets_var}}")
   else()
    set(targets_list "")
   endif()
   set("${fld_TARGETS_VAR}" "${targets_list}" PARENT_SCOPE)
   unset(targets_list)
  endif()

  #Populate dependency and add it to the build
  foreach(dep_to_pop ${${deps_var}})
   FetchContent_Populate(${dep_to_pop})
   add_subdirectory(${${dep_to_pop}_SOURCE_DIR} ${${dep_to_pop}_BINARY_DIR})
  endforeach()
 endif()
endfunction()
