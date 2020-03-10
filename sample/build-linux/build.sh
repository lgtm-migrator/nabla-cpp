#!/bin/bash
set -e
#set -xv

unset SCONS

export PROJECT_TARGET_PATH=${WORKSPACE}/target
export ENABLE_MEMCHECK=true
export UNIT_TESTS=true
export CHECK_FORMATTING=true
#export ENABLE_CLANG=true
#export ENABLE_EXPERIMENTAL=true
#export SONAR_PROCESSOR="x86-64"
export MODE_RELEASE=

if [ -n "${ENABLE_CLANG}" ]; then
    echo -e "${green} ENABLE_CLANG is defined ${happy_smiley} ${NC}"
    #AddressSanitizer to sanitize your code!
    export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer-3.8
    export ASAN_OPTIONS=alloc_dealloc_mismatch=0,symbolize=1
fi

cd ../../
#cd $PROJECT_SRC/

source ./step-2-0-0-build-env.sh || exit 1

echo -e "${cyan} ${double_arrow} Environment ${NC}"

echo "WORKSPACE ${WORKSPACE}"

pwd
#See https://github.com/fffaraz/awesome-cpp#static-code-analysis

#In Hudson
#Extract trunk/cpp in Google Code (automatic configuration)
#Batch Windows command : %WORKSPACE%\sample\build-cygwin\cmake.bat
#export PROJECT_SRC=${WORKSPACE}
#export PROJECT_TARGET_PATH=/target

echo "PROJECT_SRC : $PROJECT_SRC - PROJECT_TARGET_PATH : $PROJECT_TARGET_PATH"

./clean.sh

./conan.sh

#cd $PROJECT_SRC/sample/microsoft

#wget https://cppan.org/client/cppan-master-Linux-client.deb
#sudo dpkg -i cppan-master-Linux-client.deb
#cppan

cd "${PROJECT_SRC}/sample/build-${ARCH}"

rm -f CMakeCache.txt
rm -f compile_commands.json
#rm -f DartConfiguration.tcl

echo -e "${green} CMake ${NC}"

if [ "${OS}" == "Debian" ]; then
    echo -e "${green} CPP flags : ${NC}"

	dpkg-buildflags
	#CPPFLAGS=$(dpkg-buildflags --get CPPFLAGS)
	#CFLAGS=$(dpkg-buildflags --get CFLAGS)
	#CXXFLAGS=$(dpkg-buildflags --get CXXFLAGS)
	#LDFLAGS=$(dpkg-buildflags --get LDFLAGS)
fi

#cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug ..

if [ -n "${MODE_RELEASE}" ]; then
    echo -e "${green} MODE_RELEASE is defined ${happy_smiley} ${NC}"
    export CMAKE_INSTALL_PREFIX=/usr/local
else
    export CMAKE_INSTALL_PREFIX=$PROJECT_SRC/install/${MACHINE}/debug
fi

#-DCMAKE_C_COMPILER=i686-pc-cygwin-gcc-3.4.4 -DCMAKE_CXX_COMPILER=i686-pc-cygwin-g++-3
#-DCMAKE_ECLIPSE_GENERATE_SOURCE_PROJECT=TRUE
#-DIWYU_LLVM_ROOT_PATH=/usr/lib/llvm-3.8

#-DCMAKE_CXX_INCLUDE_WHAT_YOU_USE="/usr/bin/iwyu"
echo -e "${magenta} cmake -G\"Eclipse CDT4 - Unix Makefiles\" -DCMAKE_BUILD_TYPE=debug -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} ../microsoft ${NC}"
cmake -G"Eclipse CDT4 - Unix Makefiles" -DCMAKE_BUILD_TYPE=debug -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} ../microsoft
#-DENABLE_TESTING=true
cmake_res=$?
if [[ $cmake_res -ne 0 ]]; then
    echo -e "${red} ---> CMake failed : $cmake_res ${NC}"
    exit 1
fi

if [[ -f ../microsoft/compile_commands.json ]]; then
    rm ../microsoft/compile_commands.json
    ln -s $PWD/compile_commands.json ../microsoft/
fi

echo -e "${green} Building : CMake ${NC}"

echo -e "${magenta} ${SONAR_CMD} ${MAKE} -B clean install test DoxygenDoc package ${NC}"
${SONAR_CMD} ${MAKE} -B clean install test DoxygenDoc package
#~/build-wrapper-linux-x86/build-wrapper-linux-${PROCESSOR} --out-dir ${WORKSPACE}/bw-outputs ${MAKE} -B clean install DoxygenDoc
build_res=$?
if [[ $build_res -ne 0 ]]; then
    echo -e "${red} ---> Build failed : $build_res ${NC}"
    exit 1
fi

if [ `uname -s` == "Linux" ]; then
    echo -e "${green} Checking include : IWYU ${NC}"

	if [ -f /usr/bin/iwyu_tool.py ]; then
		echo -e "${magenta} iwyu_tool.py -p . ${NC}"
		iwyu_tool.py -p .
	fi

	if [ -f /usr/bin/iwyu_tool ]; then
		echo -e "${magenta} iwyu_tool -p . ${NC}"
		iwyu_tool -p .
	fi
fi

echo -e "${green} Testing : CTest ${NC}"

if [[ "${UNIT_TESTS}" == "true" ]]; then

    if [[ "${ENABLE_MEMCHECK}" == "true" ]]; then

      if [ `uname -s` == "Linux" ]; then
         echo -e "${green} Checking memory leak : CTest ${NC}"

         echo -e "${magenta} ctest --output-on-failure -j2 -N -D ExperimentalMemCheck ${NC}"
         #ctest -T memcheck
         ctest --output-on-failure -j2 -N -D ExperimentalMemCheck
      fi

    else
      echo -e "${magenta} ctest --output-on-failure -j2 ${NC}"
      ctest --output-on-failure -j2
    fi

    #ctest -D Experimental
    #cd ${WORKSPACE}/sample/build-linux/src/test/cpp
    #ctest .. -R circular_queueTest
    #cd src/test/app/
    #ctest -V -C Debug
    echo -e "${magenta} ctest --force-new-ctest-process --no-compress-output -T Test -O Test.xml || /bin/true ${NC}"
    ctest -V --force-new-ctest-process --no-compress-output -T Test -O Test.xml || /bin/true

    #ctest -j4 -DCTEST_MEMORYCHECK_COMMAND="/usr/bin/valgrind" -DMemoryCheckCommand="/usr/bin/valgrind" --output-on-failure -T memcheckctest -j4 -DCTEST_MEMORYCHECK_COMMAND="/usr/bin/valgrind" -DMemoryCheckCommand="/usr/bin/valgrind" --output-on-failure -T memcheck

    #${MAKE} tests
fi

if [ `uname -s` == "Linux" ]; then
    echo -e "${green} Fixing include : IWYU ${NC}"

    echo -e "${magenta} ${MAKE} clean ${NC}"
    ${MAKE} clean
    echo -e "${magenta} ${MAKE} -k CXX=/usr/bin/iwyu  2> ./iwyu.out ${NC}"
    ${MAKE} -k CXX=/usr/bin/iwyu  2> ./iwyu.out
    echo -e "${magenta} fix_includes.py < ./iwyu.out ${NC}"
    if [[ ! -f ./fix_includes.py ]]; then
        wget https://github.com/vancegroup-mirrors/include-what-you-use/blob/master/fix_includes.py && chmod 777 fix_includes.py || true
    fi
    if [[ -f ./fix_includes.py ]]; then
        ./fix_includes.py < ./iwyu.out
    fi
fi

if [[ "${ENABLE_EXPERIMENTAL}" == "true" ]]; then

    echo -e "${green} Experimental : CMake ${NC}"

    echo -e "${magenta} ${MAKE} Experimental ${NC}"
    ${MAKE} Experimental

fi

echo -e "${green} Packaging : CPack ${NC}"

#cmake --help-module CPackDeb
#cpack

echo -e "${magenta} cd $PROJECT_SRC/sample/build-${ARCH} ${NC}"
cd $PROJECT_SRC/sample/build-${ARCH}
echo -e "${magenta} ${MAKE} package ${NC}"
${MAKE} package
# To use this:
# ${MAKE} package
# sudo dpkg -i MICROSOFT-10.02-Linux.deb

if [ `uname -s` == "Linux" ]; then
    echo -e "${green} Packaging : checkinstall ${NC}"

    echo -e "${magenta} checkinstall --version ${NC}"
    checkinstall --version

    #sudo dpkg -r nabla-microsoft || true

#sudo -k checkinstall \
#--install=no
#--pkgsource="https://github.com/AlbanAndrieu/nabla-cpp" \
#--pkglicense="GPL2" \
#--deldesc=no \
#--pkgrelease="SNAPSHOT" \
#--maintainer="Alban Andrieu \\<alban.andrieu@free.fr\\>" \
#--requires="libc6 \(\>= 2.4\),libgcc1 \(\>= 1:4.1.1\),libncurses5 \(\>= 5.5-5~\),libstdc++6 \(\>= 4.1.1\),libboost-thread-dev,libboost-date-time-dev,libboost-system-dev" \
#--pkgname=nabla-microsoft --pkggroup=nabla --pkgversion=1.0.0
#
fi

if [ `uname -s` == "Linux" ]; then
    echo -e "${green} Reporting : Junit ${NC}"

    echo -e "${magenta} xsltproc CTest2JUnit.xsl Testing/`head -n 1 < Testing/TAG`/Test.xml > Testing/JUnitTestResults.xml ${NC}"
    xsltproc CTest2JUnit.xsl Testing/`head -n 1 < Testing/TAG`/Test.xml > Testing/JUnitTestResults.xml || true
fi

if [ `uname -s` == "Linux" ]; then
    echo -e "${green} Reporting : Clang analyzer ${NC}"

    #http://clang-analyzer.llvm.org/installation.html
    #http://clang-analyzer.llvm.org/scan-build.html
    echo -e "${magenta} scan-build make ${NC}"
    scan-build make
    #scan-view
fi

echo -e "${green} Reporting : Coverage ${NC}"

#TODO http://cppncss.sourceforge.net/installation.html

#TODO https://github.com/SonarOpenCommunity/sonar-cxx/blob/master/sonar-cxx-plugin/src/samples/SampleProject2/Makefile

#find . -type f \( -iname \*.gcno -or -iname \*.gcda \) -exec rm  {} -f \;
find . -type f \( -iname \*.gcno -or -iname \*.gcda \) -exec cp {} ../../ \;

echo -e "${magenta} find ../.. -name '*.gcda' ${NC}"
find ../.. -name '*.gcda'
find ../.. -name '*.gcno'

mkdir ${WORKSPACE}/reports || true
gcovr -v -r ${WORKSPACE}/sample/microsoft/ -f ${WORKSPACE}/sample/microsoft/
#xml
echo -e "${magenta} gcovr --branches --xml-pretty -r ${WORKSPACE}/microsoft/ ${NC}"
sudo gcovr --branches --xml-pretty -r ${WORKSPACE}/sample/microsoft/ > ${WORKSPACE}/reports/gcovr-report.xml
#html
echo -e "${magenta} gcovr --branches -r ${WORKSPACE}/microsoft/ --html --html-details -o ${WORKSPACE}/reports/gcovr-report.html ${NC}"
sudo gcovr --branches -r ${WORKSPACE}/sample/microsoft/ --html --html-details -o ${WORKSPACE}/reports/gcovr-report.html

echo -e "${magenta} sudo perf record -g -- /usr/bin/git --version ${NC}"
sudo perf record -g -- /usr/bin/git --version
echo -e "${magenta} sudo perf script | c++filt | gprof2dot -f perf | dot -Tpng -o output.png ${NC}"
sudo perf script | c++filt | gprof2dot -f perf | dot -Tpng -o output.png
#eog output.png

#bash -c 'find src -regex ".*\.cc\|.*\.hh" | vera++ - -showrules -nodup |& vera++Report2checkstyleReport.perl > $(BUILD_DIR)/vera++-report.xml'

#Objective C
#xcodebuild | xcpretty
#scan-build xcodebuild

echo -e "${magenta} cmake --graphviz=test.dot . ${NC}"
cmake --graphviz=test.dot .

if [[ "${CHECK_FORMATTING}" == "true" ]]; then

    echo -e "${magenta} cd ../../sample/microsoft ${NC}"
    cd $PROJECT_SRC/sample/microsoft
    echo -e "${magenta} $PROJECT_SRC/cpplint.sh ${NC}"
    $PROJECT_SRC/cpplint.sh

    # Find non-ASCII characters in headers
    hpps=$(find $PROJECT_SRC/sample/microsoft/src -name \*\.h)
    cpps=$(find $PROJECT_SRC/sample/microsoft/src -name \*\.cpp)
    echo -e "${magenta} pcregrep --color='auto' -n \"[\x80-\xFF]\" ${hpps} ${cpps} ${NC}"
    pcregrep --color='auto' -n "[\x80-\xFF]" ${hpps} ${cpps} || true
    #if [[ $? -ne 1 ]]; then exit 1; fi
    # F001: Source files should not use the '\r' (CR) character
    # L001: No trailing whitespace at the end of lines
    # L002: Don't use tab characters
    echo -e "${magenta} find $PROJECT_SRC/sample/microsoft/src -name \*\.h | vera++ --rule F001 --rule L001 --rule L002 --error ${hpps} ${cpps} ${NC}"
    find $PROJECT_SRC/sample/microsoft/src -name \*\.h | vera++ --rule F001 --rule L001 --rule L002 --error
fi

echo -e "${green} Clang tidy/format ${NC}"

#http://clang.llvm.org/docs/HowToSetupToolingForLLVM.html
##clang-format -style=llvm -dump-config > .clang-format
#clang-format -dump-config
#${MAKE} check-all
#clang-tidy -dump-config
clang-tidy $PROJECT_SRC/sample/microsoft/src/main/app/run_app.cpp

echo "http://192.168.0.28/cdash/user.php"
echo "http://maven.nabla.mobi/cpp/microsoft/index.html"

exit 0
