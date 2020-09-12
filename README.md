# cmake-utils
A set of utility scripts and functions to ease the setup of complex CMake build pipelines.

Current utilities:
 - [cmake-bootstrap](https://github.com/Matthewacon/cmake-utils#cmake-bootstrap)
 - [cmake-download](https://github.com/Matthewacon/cmake-utils#cmake-download)

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

#### Example
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

## License
[M.I.T.](https://github.com/Matthewacon/cmake-utils/blob/master/LICENSE)
