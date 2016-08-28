
@echo off
setlocal EnableDelayedExpansion

set script_location=%~dp0
set "idl_location=%script_location%srcIdl"
set "classic_cpp_folder=%script_location%srcCpp"
set "modern_cpp_folder=%script_location%srcCpp03"
set "cs_folder=%script_location%srcCs"
set "java_folder=%script_location%srcJava"
set "java_scripts_folder=%script_location%resource\java_scripts"
set "bin_folder=%script_location%bin"

@REM # Default values:
set BUILD_CPP=1
set BUILD_CPP03=1
set BUILD_CS=1
set BUILD_JAVA=1
set MSBUILD_EXE=msbuild
set JAVAC_EXE=javac
set JAVA_EXE=java
set JAR_EXE=jar

set RELEASE_DEBUG=release
set STATIC_DYNAMIC=static
set USE_SECURE_LIBS=0

# Needed when compiling statically using security
set RTI_OPENSSLHOME=""

::------------------------------------------------------------------------------

@REM # Initial message
echo ================================== PERFTEST: ===================================

::------------------------------------------------------------------------------

@REM # PARSE ARGUMENTS

if "%1"=="" (
	call:help
	exit /b 1
)
:parse_arguments
if NOT "%1"=="" (
		if "%1"=="--clean" (
			call:clean
			exit /b 0
		) ELSE if "%1"=="--help" (
				call:help
				exit /b 0
		) ELSE if "%1"=="-h" (
				call:help
				exit /b 0
		) ELSE if "%1"=="--skip-java-build" (
				SET BUILD_JAVA=0
		) ELSE if "%1"=="--skip-cpp-build" (
				SET BUILD_CPP=0
		) ELSE if "%1"=="--skip-cpp03-build" (
				SET BUILD_CPP03=0
		) ELSE if "%1"=="--skip-cs-build" (
				SET BUILD_CS=0
		) ELSE if "%1"=="--debug" (
				SET RELEASE_DEBUG=debug
		) ELSE if "%1"=="--dynamic" (
				SET STATIC_DYNAMIC=dynamic
		) ELSE if "%1"=="--secure" (
				SET USE_SECURE_LIBS=1
		) ELSE if "%1"=="--msbuild" (
				SET MSBUILD_EXE=%2
				SHIFT
		) ELSE if "%1"=="--java-home" (
				SET "JAVAC_EXE=%2\bin\javac"
				SET "JAVA_EXE=%2\bin\java"
				SET "JAR_EXE=%2\bin\jar"
				SHIFT
		) ELSE if "%1"=="--platform" (
				SET architecture=%2
				SHIFT
		) ELSE if "%1"=="--openssl-home" (
				SET "RTI_OPENSSLHOME=%2"
				SHIFT
		) ELSE if "%1"=="--nddshome" (
				SET "=%2"
				SHIFT
		) ELSE (
				echo [ERROR]: Unknown argument "%1"
				call:help
				exit /b 1
		)
		SHIFT
		GOTO :parse_arguments
)

::------------------------------------------------------------------------------

if not exist "%NDDSHOME%" (
		echo [ERROR]: The NDDSHOME variable is not set.
		exit /b 1
)

if !BUILD_CPP! == 1 (
	call !MSBUILD_EXE! /version > nul
	if not !ERRORLEVEL! == 0 (
		echo [WARNING]: !MSBUILD_EXE! executable not found, perftest_cpp will not be built.
		set BUILD_CPP=0
	)
)
if !BUILD_CPP03! == 1 (
	call !MSBUILD_EXE! /version > nul
	if not !ERRORLEVEL! == 0 (
		echo [WARNING]: !MSBUILD_EXE! executable not found, perftest_cpp03 will not be built.
		set BUILD_CPP03=0
	)
)
if !BUILD_CS! == 1 (
	call !MSBUILD_EXE! /version > nul
	if not !ERRORLEVEL! == 0 (
		echo [WARNING]: !MSBUILD_EXE! executable not found, perftest_cs will not be built.
		set BUILD_CS=0
	)
)

if !BUILD_JAVA! == 1 (
	call !JAVAC_EXE! -version > nul 2>nul
	if not !ERRORLEVEL! == 0 (
		echo [WARNING]: !JAVAC_EXE! executable not found, perftest_java will not be built.
		set BUILD_JAVA=0
	)
)
::------------------------------------------------------------------------------

@REM # This calls the function in charge of getting the name of the solution for C++
@REM # given the architecture.
call::get_solution_name

set "rtiddsgen_executable=!NDDSHOME!/bin/rtiddsgen.bat"
set "classic_cpp_lang_string=C++"
set "modern_cpp_lang_string=C++03"
set "cs_lang_string=C#"
set "java_lang_string=java"

::------------------------------------------------------------------------------
if !BUILD_CPP! == 1 (

	call::solution_compilation_flag_calculation

	if !USE_SECURE_LIBS! == 1 (
		set "ADDITIONAL_DEFINES=RTI_SECURE_PERFTEST"
		if "x!STATIC_DYNAMIC!" == "xdynamic" (
			set "ADDITIONAL_DEFINES=!ADDITIONAL_DEFINES! RTI_PERFTEST_DYNAMIC_LINKING"
		) else (
			if "x!RTI_OPENSSLHOME!" == "x" (
				echo [ERROR]: In order to link statically using the security plugin you need to also provide the OpenSSL home path by using the --openssl-home option.
				exit /b 1
			)
			set rtiddsgen_extra_options=-additionalRtiLibraries nddssecurity -additionalLibraries "libeay32z ssleay32z"
			set rtiddsgen_extra_options=!rtiddsgen_extra_options! -additionalLibraryPaths "!RTI_OPENSSLHOME!\static_!RELEASE_DEBUG!\lib"
			echo [INFO] Using security plugin. Linking Statically.
		)
	)
	set "ADDITIONAL_DEFINES=/0x !ADDITIONAL_DEFINES!"

	@REM # Generate files for srcCpp
	echo[
	echo [INFO]: Generating types and makefiles for %classic_cpp_lang_string%
	call "%rtiddsgen_executable%" -language %classic_cpp_lang_string% -replace^
	-create typefiles -create makefiles -platform %architecture%^
	-additionalHeaderFiles "MessagingIF.h RTIDDSImpl.h perftest_cpp.h"^
	-additionalSourceFiles "RTIDDSImpl.cxx" -additionalDefines "!ADDITIONAL_DEFINES!"^
	!rtiddsgen_extra_options!^
	-d "%classic_cpp_folder%" "%idl_location%\perftest.idl"
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure generating code for %classic_cpp_lang_string%.
		exit /b 1
	)
	call copy "%classic_cpp_folder%"\perftest_publisher.cxx "%classic_cpp_folder%"\perftest_subscriber.cxx

	echo[
	echo [INFO]: Compiling %classic_cpp_lang_string%
	echo call !MSBUILD_EXE! /p:Configuration="!solution_compilation_mode_flag!" "%classic_cpp_folder%"\%solution_name_cpp%
	call !MSBUILD_EXE! /p:Configuration="!solution_compilation_mode_flag!" "%classic_cpp_folder%"\%solution_name_cpp%
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure compiling code for %classic_cpp_lang_string%.
		exit /b 1
	)

	echo [INFO]: Copying perftest_cpp executable file:
	md "%bin_folder%"\%architecture%\!RELEASE_DEBUG!
	copy /Y "%classic_cpp_folder%"\objs\%architecture%\perftest_publisher.exe "%bin_folder%"\%architecture%\!RELEASE_DEBUG!\perftest_cpp.exe
)

if !BUILD_CPP03! == 1 (

	call::solution_compilation_flag_calculation

	if !USE_SECURE_LIBS! == 1 (
		set "ADDITIONAL_DEFINES=RTI_SECURE_PERFTEST"
		if "x!STATIC_DYNAMIC!" == "xdynamic" (
			set "ADDITIONAL_DEFINES=!ADDITIONAL_DEFINES! RTI_PERFTEST_DYNAMIC_LINKING"
		) else (
			if "x!RTI_OPENSSLHOME!" == "x" (
				echo [ERROR]: In order to link statically using the security plugin you need to also provide the OpenSSL home path by using the --openssl-home option.
				exit /b 1
			)
			set rtiddsgen_extra_options=-additionalRtiLibraries nddssecurity -additionalLibraries "libeay32z ssleay32z"
			set rtiddsgen_extra_options=!rtiddsgen_extra_options! -additionalLibraryPaths "!RTI_OPENSSLHOME!\static_!RELEASE_DEBUG!\lib"
			echo [INFO] Using security plugin. Linking Statically.
		)
	)
	set "ADDITIONAL_DEFINES=/0x !ADDITIONAL_DEFINES!"

	@REM #Generate files for srcCpp03
	echo[
	echo [INFO]: Generating types and makefiles for %modern_cpp_lang_string%
	call "%rtiddsgen_executable%" -language %modern_cpp_lang_string% -replace^
	-create typefiles -create makefiles -platform %architecture%^
	-additionalHeaderFiles "MessagingIF.h RTIDDSImpl.h perftest_cpp.h"^
	-additionalSourceFiles "RTIDDSImpl.cxx" -additionalDefines "!ADDITIONAL_DEFINES!"^
	!rtiddsgen_extra_options!^
	-d "%modern_cpp_folder%" "%idl_location%\perftest.idl"

	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure generating code for %modern_cpp_lang_string%.
		exit /b 1
	)
	call copy "%modern_cpp_folder%"\perftest_publisher.cxx "%modern_cpp_folder%"\perftest_subscriber.cxx

	echo[
	echo [INFO]: Compiling %modern_cpp_lang_string%
	echo call !MSBUILD_EXE! /p:Configuration="!solution_compilation_mode_flag!" "%modern_cpp_folder%"\%solution_name_cpp%
	call !MSBUILD_EXE! /p:Configuration="!solution_compilation_mode_flag!" "%modern_cpp_folder%"\%solution_name_cpp%
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure compiling code for %modern_cpp_lang_string%.
		exit /b 1
	)

	echo [INFO]: Copying perftest_cpp executable file:
	md "%bin_folder%"\%architecture%\!RELEASE_DEBUG!
	copy /Y "%modern_cpp_folder%"\objs\%architecture%\perftest_publisher.exe "%bin_folder%"\%architecture%\!RELEASE_DEBUG!\perftest_cpp03.exe
)

::------------------------------------------------------------------------------

if %BUILD_CS% == 1 (

	@REM Generate files for srcCs
	echo[
	echo [INFO]: Generating types and makefiles for %cs_lang_string%
	call "%rtiddsgen_executable%" -language %cs_lang_string% -replace^
	-create typefiles -create makefiles -platform %architecture%^
	-additionalSourceFiles "RTIDDSImpl.cs MessagingIF.cs"^
	-additionalDefines "/0x" -d "%cs_folder%" "%idl_location%\perftest.idl"
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure generating code for %cs_lang_string%.
		exit /b 1
	)
	call copy "%cs_folder%"\perftest_publisher.cs "%cs_folder%"\perftest_subscriber.cs

	echo[
	echo [INFO]: Compiling %cs_lang_string%
  echo call !MSBUILD_EXE! /p:Configuration=!RELEASE_DEBUG! "%cs_folder%"\%solution_name_cs%
	call !MSBUILD_EXE! /p:Configuration=!RELEASE_DEBUG! "%cs_folder%"\%solution_name_cs%
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure compiling code for %cs_lang_string%.
		exit /b 1
	)

	echo [INFO]: Copying files
	md "%bin_folder%"\%architecture%\!RELEASE_DEBUG!
	copy /Y "%cs_folder%"\%cs_bin_path%\perftest_publisher.exe "%bin_folder%"\%architecture%\!RELEASE_DEBUG!\perftest_cs.exe
	copy /Y "%cs_folder%"\%cs_bin_path%\perftest_*.dll "%bin_folder%"\%architecture%\!RELEASE_DEBUG!
	copy /Y "%cs_folder%"\%cs_bin_path%\nddsdotnet*.dll "%bin_folder%"\%architecture%\!RELEASE_DEBUG!
)

::------------------------------------------------------------------------------

if	%BUILD_JAVA% == 1 (

	@REM Generate files for Java
	echo[
	echo [INFO]: Generating types and makefiles for %java_lang_string%
	call "%rtiddsgen_executable%" -language %java_lang_string% -replace^
	-package com.rti.perftest.gen -d "%java_folder%" "%idl_location%\perftest.idl"
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure generating code for %java_lang_string%.
		exit /b 1
	)
	call md "%java_folder%"\class
	call md "%java_folder%"\jar\!RELEASE_DEBUG!

	echo[
	if x!RELEASE_DEBUG! == xrelease (
		echo [INFO]: Compiling against nddsjava.jar library
		set "rti_ndds_java_jar=%NDDSHOME%/lib/java/nddsjava.jar"
	) else (
		echo [INFO]: Compiling against nddsjavad.jar library
	set "rti_ndds_java_jar=%NDDSHOME%/lib/java/nddsjavad.jar"
	)

	echo[
	echo [INFO]: Doing javac
	call "%JAVAC_EXE%" -d "%java_folder%"/class -cp !rti_ndds_java_jar!^
	"%java_folder%"/com/rti/perftest/*.java^
	"%java_folder%"/com/rti/perftest/ddsimpl/*.java^
	"%java_folder%"/com/rti/perftest/gen/*.java^
	"%java_folder%"/com/rti/perftest/harness/*.java
	if not !ERRORLEVEL! == 0 (
		echo [ERROR]: Failure compiling code for %java_lang_string%.
		exit /b 1
	)

	echo [INFO]: Generating jar
	"%JAR_EXE%" cf "%java_folder%"\jar\!RELEASE_DEBUG!\perftest_java.jar^
	-C "%java_folder%"\class .

	echo [INFO]: Copying files
	md "%bin_folder%"\!RELEASE_DEBUG!
	copy "%java_folder%"\jar\!RELEASE_DEBUG!\perftest_java.jar "%bin_folder%"\!RELEASE_DEBUG!\perftest_java.jar
	copy "%java_scripts_folder%"\perftest_java.bat "%bin_folder%"\!RELEASE_DEBUG!\perftest_java.bat
	echo [INFO]: Files copied

	echo[
	echo [INFO]: You can run the java .jar file by using the following command:
	echo[
	echo "%JAVA_EXE%" -Xmx1500m -cp "%bin_folder%\!RELEASE_DEBUG!\perftest_java.jar;%NDDSHOME%\lib\java\nddsjava.jar" com.rti.perftest.ddsimpl.PerfTestLauncher
	echo[
	echo You will need to set the PATH variable for this script.
	echo[
	echo [INFO]: Or by running:
	echo[
	echo "%bin_folder%"\!RELEASE_DEBUG!\perftest_java.bat
	echo[
	echo You will need to set the NDDSHOME and RTI_PERFTEST_ARCH for this script.
	echo[
	echo [INFO]: Compilation successful

)

echo[
echo ================================================================================
GOTO:EOF

::------------------------------------------------------------------------------
@REM #FUNCTIONS:

:get_solution_name
	if not x%architecture:x64=%==x%architecture% (
		set begin_sol=perftest_publisher-64-
		set begin_sol_cs=perftest-64-
		set cs_64=x64\
	) else (
		set begin_sol=perftest_publisher-
		set begin_sol_cs=perftest-
	)
	if not x%architecture:VS2008=%==x%architecture% (
		set end_sol=vs2008
		set extension=.vcproj
	)
	if not x%architecture:VS2010=%==x%architecture% (
		set end_sol=vs2010
		set extension=.vcxproj
	)
	if not x%architecture:VS2012=%==x%architecture% (
		set end_sol=vs2012
		set extension=.vcxproj
	)
	if not x%architecture:VS2013=%==x%architecture% (
		set end_sol=vs2013
		set extension=.vcxproj
	)
	if not x%architecture:VS2015=%==x%architecture% (
		set end_sol=vs2015
		set extension=.vcxproj
	)
	set solution_name_cpp=%begin_sol%%end_sol%%extension%
	set solution_name_cs=%begin_sol_cs%csharp.sln
	set cs_bin_path=bin\%cs_64%!RELEASE_DEBUG!-%end_sol%
GOTO:EOF

:solution_compilation_flag_calculation
  echo[

	set "solution_compilation_mode_flag="
	if x!STATIC_DYNAMIC!==xdynamic (
		set "solution_compilation_mode_flag= DLL"
  )
  if x!RELEASE_DEBUG!==xdebug (
		set solution_compilation_mode_flag=debug!solution_compilation_mode_flag!
  ) else (
		set solution_compilation_mode_flag=release!solution_compilation_mode_flag!
  )

	echo [INFO]: Compilation flag for msbuild is: !solution_compilation_mode_flag!

GOTO:EOF

:help
	echo[
	echo This scripts accepts the following parameters:
	echo[
	echo.	--platform your_arch		 Platform for which build.sh is going to compile
	echo.								 RTI Perftest.
	echo.	--nddshome path			  Path to the *RTI Connext DDS installation*. If
	echo.								 this parameter is not present, the \$NDDSHOME
	echo.								 variable should be set.
	echo.	--skip-java-build			Avoid Java ByteCode generation creation.
	echo.	--skip-cpp-build			 Avoid C++ code generation and compilation.
	echo.	--skip-cpp03-build		   Avoid C++ New PSM code generation and
	echo.								 compilation.
	echo.	--skip-cs-build			  Avoid C Sharp code generation and compilation.
	echo.	--make  path				 Path to the GNU make executable. If this
	echo.								 parameter is not present, GNU make variable
	echo.								 should be available from your \$PATH variable.
	echo.	--java-home path			 Path to the Java JDK home folder. If this
	echo.								 parameter is not present, javac, jar and java
	echo.								 executables should be available from your
	echo.								 \$PATH variable.
	echo.	--debug					  Compile against the RTI Connext Debug
	echo.								 libraries. Default is against release ones.
	echo.	--dynamic					Compile against the RTI Connext Dynamic
	echo.								 libraries. Default is against static ones.
	echo.	--secure					 Enable the security options for compilation.
	echo.								 Default is not enabled.
	echo.	--openssl-home path		  Path to the openssl home. This will be used
	echo.								 when compiling statically and using security
	echo.	--clean					  If this option is present, the build.sh script
	echo.								 will clean all the generated code and binaries
	echo.								 from previous executions.
	echo.	--help -h					Display this message.
	echo[
	echo ================================================================================
GOTO:EOF

:clean
	echo[
	echo Cleaning generated files.

	rmdir /s /q %script_location%srcCpp\objs > nul 2>nul
	del %script_location%srcCpp\*.vcxproj > nul 2>nul
	del %script_location%srcCpp\*.vcproj > nul 2>nul
	del %script_location%srcCpp\*.filters > nul 2>nul
	del %script_location%srcCpp\*.sln > nul 2>nul
	del %script_location%srcCpp\perftest.* > nul 2>nul
	del %script_location%srcCpp\perftestPlugin.* > nul 2>nul
	del %script_location%srcCpp\perftestSupport.* > nul 2>nul
	del %script_location%srcCpp\perftest_subscriber.cxx > nul 2>nul
	rmdir /s /q %script_location%srcCpp03\objs > nul 2>nul
	del %script_location%srcCpp03\*.vcxproj > nul 2>nul
	del %script_location%srcCpp03\*.vcproj > nul 2>nul
	del %script_location%srcCpp03\*.filters > nul 2>nul
	del %script_location%srcCpp03\*.sln > nul 2>nul
	del %script_location%srcCpp03\perftest.* > nul 2>nul
	del %script_location%srcCpp03\perftestImplPlugin.* > nul 2>nul
	del %script_location%srcCpp03\perftestImpl.* > nul 2>nul
	del %script_location%srcCpp03\perftest_subscriber.cxx > nul 2>nul
	rmdir /s /q %script_location%srcCs\obj > nul 2>nul
	rmdir /s /q %script_location%srcCs\bin > nul 2>nul
	del %script_location%srcCs\*.vcxproj > nul 2>nul
	del %script_location%srcCs\*.vcproj > nul 2>nul
	del %script_location%srcCs\*.filters > nul 2>nul
	del %script_location%srcCs\*.sln > nul 2>nul
	del %script_location%srcCs\perftest.* > nul 2>nul
	del %script_location%srcCs\perftest_subscriber.cs > nul 2>nul
	rmdir /s /q %script_location%bin > nul 2>nul
	rmdir /s /q %script_location%srcJava\class > nul 2>nul
	rmdir /s /q %script_location%srcJava\jar > nul 2>nul

	echo[
	echo ================================================================================
GOTO:EOF