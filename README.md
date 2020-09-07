# cmake-download
A simple cmake function to download a cmake-based project without all the fuss
of `ExternalProject_Add`.

## Setup 
### Submodule
Add this repository as a submodule to you CMake-based repository:
```sh
git submodule add git@github.com:Matthewacon/cmake-download.git
```
then include the download file in your in your top-level `CMakeLists.txt`:
```cmake
include(cmake-download/download.cmake)
```

### Single file download
Download the `cmake-download.cmake` file into the root of your repository:
```sh
curl https://raw.githubusercontent.com/Matthewacon/cmake-download/master/cmake-download.cmake -o cmake-download.cmake -s
```
then include the file in your top-level `CMakeLists.txt`:
```sh
include(cmake-download.cmake)
```

## Usage
Invoke the `find_or_download` function with the required and any one, or
more, of the optional arguments:
| Argument | - | Description |
| :-- | :-- | :-- |
| `PACKAGE_NAME` | REQUIRED | The name of the package to find |
| `VERSION` | OPTIONAL | The version of the package to find |
| `GIT_REPO` | REQIORED | The repository to download if the package is not found |
| `GIT_TAG` | OPTIONAL | A branch, tag or commit hash, defaults to 'master' |
| `STATUS_VAR` | OPTIONAL | The variable to store the download status on, set to `TRUE` if downloaded 
| `DEPS_DIR` | OPTIONAL | Download destination, defaults to `${CMAKE_SOURCE_DIR}/dependencies` |
| `DOWNLOAD_OVERRIDE` | OPTIONAL | Force downloading of sources |

### Example
```cmake
cmake_minimum_required(VERSION 3.8)
include(cmake-download/cmake-download.cmake)

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
[M.I.T.](https://github.com/Matthewacon/cmake-download/blob/master/LICENSE).
