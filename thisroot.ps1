rem The `latest-stable` branch gets updated automatically on each release.
rem You may update your local copy by issuing a `git pull` command from within `root_src`.
C:\Users\luisf>git clone --branch latest-stable --depth=1 https://github.com/root-project/root.git root_src
C:\Users\luisf>mkdir root_build root_install && cd root_build
C:\Users\luisf>cmake -G"Visual Studio 16 2019" -A Win32 -Thost=x64 -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_INSTALL_PREFIX=../root_install ../root_src
C:\Users\luisf>cmake --build . --config Release --target install
C:\Users\luisf>..\root_install\bin\thisroot.bat
