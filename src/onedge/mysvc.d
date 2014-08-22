module mysvc;
import std.stdio;
import core.thread;
import std.conv : to;
import std.process : system;
import std.stdio;
import std.string;
import win32.w32api;
import win32.winbase;
import win32.winerror;
import win32.winnt;
import win32.windef;
import win32.winsvc;

import winsvc.svcbase;

class MyService : ServiceBase
{
private:
    HANDLE _stopServiceEvent = null;
    bool _stopping;

public:
    this(string serviceName,
         string displayName,
         bool canStop = true, 
         bool canShutdown = true, 
         bool canPauseContinue = false)
    {
        super(serviceName, displayName, canStop, canShutdown, canPauseContinue);
    }

protected:
    // Executes when a Start command is sent to the service by the SCM or 
    // when the operating system starts (for a service that starts automatically). 
    // Specifies actions to take when the service starts.
    override void OnStart(string[] args)
    {
        debug logIt("OnStart called");
        // do initialisation here
        _stopServiceEvent = CreateEvent(null, FALSE, FALSE, null);
        if (!_stopServiceEvent)
        {
            debug logIt("CreateEvent failed.");
        }

        //worker thread - normally some other class
        auto web = new Thread( 
                         { 
                             Sleep(3000);
                             debug logItWt("worker pid: ", getpid());
                             while (!_stopping)
                             {
                                 Sleep(5000);
                                 logItWt("worker thread");
                             }
                             SetEvent(cast (HANDLE) _stopServiceEvent);
                         });
        web.isDaemon = true;
        web.start();
    }

    // Executes when a Stop command is sent to the service by the SCM. 
    // Specifies actions to take when a service stops running.
    override void OnStop()
    {
        debug logIt("OnStop called");
        _stopping = true; //tell worker thread to stop

        //wait for signal
        if (WaitForSingleObject(_stopServiceEvent, INFINITE) != WAIT_OBJECT_0)
        {
            auto err = GetLastError();
            throw new Exception("Error: %s", to!string(err));
        }

        // service was stopped signaled and SERVICE_STOP_PENDING set already - so clean up
        CloseHandle(_stopServiceEvent);
        _stopServiceEvent = null;
    }

    override void OnPause() {}
    override void OnContinue() {}
    override void OnShutdown() {}

private:
    void logIt(T...)(T args)
    {
        try
        {
            File f = File(r"c:\temp\inc.log", "a");
            auto tid = GetCurrentThreadId();
            if (tid)
                f.writeln(args, ", tid: ", tid);
            else
                f.writeln(args);
        }
        catch
        {

        }
    }

    void logItWt(T...)(T args)
    {
        try
        {
            File f = File(r"c:\temp\incwt.log", "a");
            auto tid = GetCurrentThreadId();
            if (tid)
                f.writeln(args, ", tid: ", tid);
            else
                f.writeln(args);
        }
        catch
        {
        }
    }
}
