# Compiling CUDA examples gives build error

# Question

I am running Windows 7 64bit, with Visual Studio 2008. I installed the CUDA drivers and SDK. The SDK comes with quite a few examples including compiled executables and source code. The compiled executables run wonderfully. When I open the vc90 solutions and go to build in Win32 configuration I get this error:

```
Error   1   fatal error LNK1181: cannot open input file '.\Release\bandwidthTest.cu.obj'    bandwidthTest   bandwidthTest
```

Build log:

```
1>------ Build started: Project: bandwidthTest, Configuration: Release Win32 ------
1>Compiling with CUDA Build Rule...
1>"C:\CUDA\bin64\nvcc.exe"    -arch sm_10 -ccbin "c:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\bin"    -Xcompiler "/EHsc /W3 /nologo /O2 /Zi   /MT  " -I"C:\CUDA\include" -I"../../common/inc" -maxrregcount=32  --compile -o "Release\bandwidthTest.cu.obj" "c:\ProgramData\NVIDIA Corporation\NVIDIA GPU Computing SDK\C\src\bandwidthTest\bandwidthTest.cu" 
1>nvcc fatal   : Visual Studio configuration file '(null)' could not be found for installation at 'c:/Program Files (x86)/Microsoft Visual Studio 9.0/VC/bin/../..'
1>Linking...
1>LINK : fatal error LNK1181: cannot open input file '.\Release\bandwidthTest.cu.obj'
1>Build log was saved at "file://c:\ProgramData\NVIDIA Corporation\NVIDIA GPU Computing SDK\C\src\bandwidthTest\Release\BuildLog.htm"
1>bandwidthTest - 1 error(s), 0 warning(s)
========== Build: 0 succeeded, 1 failed, 0 up-to-date, 0 skipped ==========
```

If I attempt to compile in x64 it doesn't build at all and just skips the project

```
1>------ Skipped Build: Project: bandwidthTest ------
1> 
========== Build: 0 succeeded or up-to-date, 0 failed, 1 skipped ==========
```

I am new to C++, having been doing C# for a while. I'm certain there is something small that I am missing, but any clues you could provide would be appreciated.


---


# Accepted Answer

Check if you have x64 compiler installed. Then change project type to x64. I had the same problem when trying to compile 32bit cuda program with 64bit win7.

Also make sure you have added 64bit libs and includes to the search path.