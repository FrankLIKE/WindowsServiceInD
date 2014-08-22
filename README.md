WindowsServiceInD
=================

My stab at a reference implementation of a Windows Service in D.

My first real D programming. So if you're a D expert, don't laugh too hard.

I'm using 

 - Visual Studio 2013 and [D for Visual Studio][]. 
 - The [Windows Bindings][] with [source download][] to my C:\D\dsource directory. 
 - DMD x64 with the following commandline:
 
"$(VisualDInstallDir)pipedmd.exe" dmd -m64 -g -debug -X -Xf"$(IntDir)\$(TargetName).json" -IC:\D\dsource -deps="$(OutDir)\$(ProjectName).dep" -of"$(OutDir)\$(ProjectName).exe" -map "$(INTDIR)\$(SAFEPROJECTNAME).map"

My thanks to [Graham Fawcett][] who pointed me in the right direction and shared some code with me that unlocked many questions for me. And many thanks to [Vladimir Panteleev][] who came to my rescue when I became desperate and won the $100 bounty and applied that to the ongoing efforts to improve D. You may want to have a look at his [work on GitHub][].

Please note this is early Alpha. I've not tested it extensively but I promised Graham and Vladimir that I would share it when I got it working. For those who are curious, the original "working" code derived from the code that Graham gave me and Vladimir helped me to get working is in the src\first_success directory.

One more point. I tried to model this implementation after a reference implementation in C++ found under [A basic Windows service in C++][].

  [D for Visual Studio]: http://rainers.github.io/visuald/visuald/StartPage.html
  [Windows Bindings]: http://www.dsource.org/projects/bindings/wiki/WindowsApi
  [source download]: http://www.dsource.org/projects/bindings/browser/trunk/win32
  [Graham Fawcett]: http://forum.dlang.org/thread/ji0c24$19nl$1@digitalmars.com
  [Vladimir Panteleev]: http://forum.dlang.org/thread/rdphipetilqcxhriclde@forum.dlang.org
  [work on GitHub]: https://github.com/CyberShadow
  [A basic Windows service in C++]: http://code.msdn.microsoft.com/windowsapps/CppWindowsService-cacf4948
  