# cmake-utils
A set of utility scripts and functions to ease the setup of complex CMake build pipelines.

Current utilities:
 - [cmake-bootstrap](https://github.com/Matthewacon/cmake-utils#cmake-bootstrap)
 - [cmake-download](https://github.com/Matthewacon/cmake-utils#cmake-download)
 - [cmake-fetch](https://github.com/Matthewacon/cmake-utils#cmake-fetch)

## cmake-bootstrap
A CMake function to bootstrap other CMake projects. Allows for complex build
pipelines that, for example, require projects to be built pre-configure-time.

### Setup
The setup process is identical to the process described for
[cmake-download](https://github.com/Matthewacon/cmake-utils#setup-1), save for 
the file to include: substitute `cmake-bootstrap.cmake` for
`cmake-download.cmake`. 

### Usage
Invoke the `bootstrap_build` function with the required and any one, or more,
of the optional arguments:
| Argument | Required? | Description |
| :-- | :-- | :-- |
| `BOOTSTRAP_NAME` | REQUIRED | The name of the bootstrapped project |
| `BUILD_CMAKE_ROOT` | REQUIRED | The directory containing the 'CMakeLists.txt' of the bootstrapped project |
| `TARGET_NAME` | OPTIONAL | Common target name prefix for all bootstrap build targets, defaults to '${BOOTSTRAP_NAME}' |
| `GENERATOR` | OPTIONAL | The CMake generator to use for the bootstrapped project, defaults to 'Ninja' |
| `BUILD_COMMAND` | OPTIONAL | The build command to use for the bootstrapped porject, defaults to the generator's build command |
| `ENVIRONMENT` | OPTIONAL | A list of environment variables [VAR1=1 VAR2=2 ...] to use for the bootstrapped configure and build tasks |
| `EXTRA_CMAKE_FLAGS` | OPTIONAL | A list of CMake flags [FLAG1=1 FLAG2=2 ...] to set when configuring the bootstrapped project |
| `DEPENDS` | OPTIONAL | A list of configure dependencies |

The function will add two new targets that you can use in your project:
| Target Name | Description |
| :-- | :-- |
| `${BOOTSTRAP_NAME}_configure` | The configure task for the bootstrapped project |
| `${BOOTSTRAP_NAME}_build` | The build task for the bootstrapped project |

### Example
```cmake
cmake_minimum_required(VERSION 3.8)
include(cmake-utils/cmake-bootstrap.cmake)

bootstrap_build(
 BOOTSTRAP_NAME "example"
 BUILD_CMAKE_ROOT "path/to/example"
 ENVIRONMENT CC=clang CXX=clang++
)

#Some downstream command that depends on configure artifacts from "example"
add_custom_command(
 OUTPUT stuff
 COMMAND ${CMAKE_COMMAND} -E echo "Configured!"
 DEPENDS example_configure
)

#Another downstream command that depends on build artifacts from "example"
add_custom_command(
 OUTPUT things
 COMMAND ${CMAKE_COMMAND} -E echo "Built!"
 DEPENDS example_build
)

#The target for this project 
add_custom_target(my_custom_target ALL DEPENDS stuff things)
```

## cmake-download
A simple CMake function to download a cmake-based project without all the fuss
of `ExternalProject_Add`.

### Setup 
#### Submodule
Add this repository as a submodule to you CMake-based repository:
```sh
git submodule add git@github.com:Matthewacon/cmake-download.git
```
then include the download file in your in your top-level `CMakeLists.txt`:
```cmake
include(cmake-download/download.cmake)
```

#### Single file download
Download the `cmake-download.cmake` file into the root of your repository:
```sh
curl https://raw.githubusercontent.com/Matthewacon/cmake-utils/master/cmake-download.cmake -o cmake-download.cmake -s
```
then include the file in your top-level `CMakeLists.txt`:
```sh
include(cmake-download.cmake)
```

### Usage
Invoke the `find_or_download` function with the required and any one, or
more, of the optional arguments:
| Argument | Required? | Description |
| :-- | :-- | :-- |
| `PACKAGE_NAME` | REQUIRED | The name of the package to find |
| `VERSION` | OPTIONAL | The version of the package to find |
| `GIT_REPO` | REQUIRED | The repository to download if the package is not found |
| `GIT_TAG` | OPTIONAL | A branch, tag or commit hash, defaults to 'master' |
| `STATUS_VAR` | OPTIONAL | The variable to store the download status on, set to `TRUE` if downloaded 
| `DEPS_DIR` | OPTIONAL | Download destination, defaults to `${CMAKE_SOURCE_DIR}/dependencies` |
| `DOWNLOAD_OVERRIDE` | OPTIONAL | Force downloading of sources |

The function will add one target that you can use in your project:
| Target Name | Description |
| :-- | :-- |
| `download_${PACKAGE_NAME}` | The download task |

### Example
```cmake
cmake_minimum_required(VERSION 3.8)
include(cmake-utils/cmake-download.cmake)

find_or_download(
 PACKAGE_NAME gtest
 GIT_REPO https://github.com/google/googletest
 GIT_TAG v1.10.0
 STATUS_VAR gtest_downloaded
)

if(${gtest_downloaded})
 message(STATUS "Building gtest from source")
 include(dependencies/googletest)
 #...
else()
 message(STATUS "Using system gtest installation")
 #...
endif()
```

## cmake-fetch
cmake-fetch is an alternative to cmake-download, that allows fetching
and adding dependencies at configure time within a single build. It
has less granularity than cmake-download, but should be suitable for
most applications. If your build requires pre-configuration-time building
of dependencies, a combination of cmake-download and cmake-bootstrap should
suffice.

### Setup
The setup process is identical to the process described for
[cmake-download](https://github.com/Matthewacon/cmake-utils#setup-1), save for 
the file to include: substitute `cmake-fetch.cmake` for
`cmake-download.cmake`. 

### Usage
cmake-fetch provides two functions for declaring latent dependencies and fetching them later on:
 - [`add_latent_dependency`](https://github.com/Matthewacon/cmake-utils#add_latent_dependency) - Declares a dependency to be fetched later on in configure-time 
 - [`fetch_latent_dependencies`](https://github.com/Matthewacon/cmake-utils#fetch_latent_dependencies) - Fetches all of the latent dependencies declared using `add_latent_dependency` 

#### `add_latent_dependency`:
The `add_latent_dependency` function accepts all of the same arguments as the
`FetchContent_Declare` function, as well as a few named arguments that are
specific to itself, and are removed from the argument list when invoking
`FetchContent_Declare`:
| Argument | Required? | Description |
| :- | :- | :- |
| `SCOPE_ID` | OPTIONAL | A unique prefix for the parent-scope latent dependency list |
| `NAME` | REQUIRED | The designated name of the dependency; added to parent-scope list of dependencies |
| `TARGET_NAMES` | REQUIRED | A list of targets defined by the dependency; added to parent-scope list of link targets |

The function will invoke `FetchContent_Declare`, forwarding any arguments that
are not specific to `add_latent_dependency`, and define two variables in the
parent scope:
| VARIABLE | DESCRIPTION |
| :- | :- |
| `${SCOPE_ID}_latent_dependencies` | A list of dependency names; used internally when invoking `fetch_latent_dependencies` |
| `${SCOPE_ID}`_latent_targets | A list of targets to link against later in the build lifecycle (see [`TARGETS_VAR`](https://github.com/Matthewacon/cmake-utils#fetch_latent_dependencies)) |

Note: If the `SCOPE_ID` named variable is not specified, it defaults to `adl`.

#### `fetch_latent_dependencies`:
The `fetch_latent_dependencies` function does exactly as it says; when invoked
it will populate all of the projects defined in the list
`${SCOPE_ID}_latent_dependencies` and add include them in the build. 

| Argument | Required? | Description |
| :- | :- | :- |
| `SCOPE_ID` | OPTIONAL | A unique prefix for the parent-scope latent dependency list |
| `TARGETS_VAR` | OPTIONAL | The name of the result var for the parent-scope list of latent dependency targets |

###  Example
Simple configuration:
```cmake
cmake_minimum_required(VERSION 3.19)
project(cmake-fetch-example VERSION 0.0.1)

include(cmake-utils/cmake-fetch.cmake)

#Add googletest as a dependency
add_latent_dependency(
 gtest
 GIT_REPOSITORY https://github.com/google/googletest.git
 GIT_TAG release-1.10.0
 TARGET_NAMES gtest
)

#Add google benchmark as a dependency
add_latent_dependency(
 gbenchmark
 GIT_REPOSITORY https://github.com/google/benchmark.git
 GIT_TAG v1.5.2
 TARGET_NAMES benchmark::benchmark
)

#Configure executable
add_executable(example_binary example.cpp)

#Fetch all declared dependencies and get list of link targets
fetch_latent_dependencies(TARGETS_VAR to_link_against)

target_include_directories(
 example_binary PRIVATE 
 ${gtest_SOURCE_DIR}/include      #gtest headers
 ${gbenchmark_SOURCE_DIR}/include #gbenchmarm headers
)
target_link_libraries(example_binary ${to_link_against})
```

Configuration with multiple dependency scopes:
```cmake
cmake_minimum_required(VERSION 3.19)
project(multiscope-cmake-fetch-example VERSION 0.0.1)

#Add fmt as a main dependency
add_latent_dependency(
 fmt
 SCOPE_ID main
 GIT_REPOSITORY https://github.com/fmtlib/fmt.git
 GIT_TAG 7.1.3
)

#Add gtest as a test dependency
add_latent_dependency(
 gtest
 SCOPE_ID test
 GIT_REPOSITORY https://github.com/google/googletest.git
 GIT_TAG release-1.10.0
 TARGET_NAMES gtest
)

#Add google benchmark as test dependency
add_latent_dependency(
 gbenchmark
 SCOPE_ID test
 GIT_REPOSITORY https://github.com/google/benchmark.git
 GIT_TAG v1.5.2
 TARGET_NAMES benchmark::benchmark
)

#Configure test executable
add_executable(example_test test.cpp)

#Fetch test dependencies
fetch_latent_dependencies(
 SCOPE_ID test
 TARGETS_VAR test_libraries
)

target_include_directories(
 example_test 
 ${gtest_SOURCE_DIR}/include
 ${gbenchmark_SOURCE_DIR}/include
)
target_link_libraries(example_test ${test_libraries})

#Configure main executable
add_executable(main main.cpp)

#Fetch main dependencies
fetch_latent_dependencies(
 SCOPE_ID main
 TARGETS_VAR main_libraries 
)

target_include_directories(main ${fmt_SOURCE_DIR}/include)
target_link_libraries(main ${main_libraries})
```

## License
[M.I.T.](https://github.com/Matthewacon/cmake-utils/blob/master/LICENSE)
