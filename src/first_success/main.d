import core.sync.mutex : Mutex;
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
pragma(lib, "advapi32.lib");

enum SERVICE_NAME = "MyTestService";
enum DISPLAY_NAME = "My Test Service";
enum SERVICE_START_NAME = "NT AUTHORITY\\NetworkService"; 
enum CONTROL_PORT = 8080;

enum _MAX_PATH = 4096;

__gshared
{
    char* serviceName;
    char* displayName;
    char* serviceStartName;
    SERVICE_TABLE_ENTRY[] serviceTable;
    SERVICE_STATUS serviceStatus;
    SERVICE_STATUS_HANDLE serviceStatusHandle; //due to vlad's fix as mixin = 0;
    HANDLE stopServiceEvent = null;
    Thread web;
    DWORD checkPoint = 1;
    bool stopping = false;
}

void initialize()
{
    serviceName = cast(char*) toStringz(SERVICE_NAME);
    displayName = cast(char*) toStringz(DISPLAY_NAME);
    serviceStartName = cast(char*) toStringz(SERVICE_START_NAME);
    debug logIt("initialize");
}

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

//void ServiceControlHandler(DWORD controlCode)

extern (Windows)
DWORD ServiceControlHandler(DWORD controlCode, DWORD eventType,
                            void* eventData, void* context)
{
    debug logIt("ServiceControlHandler, controlCode ", controlCode);

    switch (controlCode)
    {
        case SERVICE_CONTROL_SHUTDOWN:
        case SERVICE_CONTROL_STOP:
            StopService();
            break;

        case SERVICE_CONTROL_SESSIONCHANGE:
        case SERVICE_CONTROL_PAUSE: // 2
        case SERVICE_CONTROL_CONTINUE: // 3
        case SERVICE_CONTROL_INTERROGATE: // 4
        default:
            //SetStatus(serviceStatus.dwCurrentState);
            break;
    }
    return NO_ERROR;
}

extern(Windows)
void ServiceMain(DWORD argc, TCHAR** argv)
{
    //auto mythread = thread_attachThis();
    debug logIt("ServiceMain pid: ", getpid(), argv);

    // initialise service status
    //with (serviceStatus)
    //{

    //DWORD dwServiceType;
    //DWORD dwCurrentState;
    //DWORD dwControlsAccepted;
    //DWORD dwWin32ExitCode;
    //DWORD dwServiceSpecificExitCode;
    //DWORD dwCheckPoint;
    //DWORD dwWaitHint;

        serviceStatus.dwServiceType		= SERVICE_WIN32_OWN_PROCESS;
        serviceStatus.dwCurrentState		= SERVICE_STOPPED;
        serviceStatus.dwControlsAccepted = 0; //|= SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN;
        serviceStatus.dwWin32ExitCode		= NO_ERROR;
        serviceStatus.dwServiceSpecificExitCode = 0;
        serviceStatus.dwCheckPoint		      = 0;
        serviceStatus.dwWaitHint		          = 3000;
    //}

    Sleep(1000); //test delay before getting handler

    serviceStatusHandle = RegisterServiceCtrlHandlerEx(serviceName,
                                                       &ServiceControlHandler, null);

    debug logIt("RegisterServiceCtrlHandler, serviceStatusHandle ", serviceStatusHandle);
    if (!serviceStatusHandle)
    {
        return;
    }

    // service is starting
    serviceStatus.dwControlsAccepted = 0; //accept no controls while pending
    auto pendStatus = SetStatus(SERVICE_START_PENDING);
    debug logIt("pendStatus ", pendStatus);

    // do initialisation here
    stopServiceEvent = CreateEvent(null, FALSE, FALSE, null);
    if (!stopServiceEvent)
    {
        debug logIt("!stopServiceEvent = CreateEvent");
    }

    //worker thread 
    web = new Thread( 
                     { 
                         Sleep(3000);
                         debug logItWt("worker pid: ", getpid());
                         //serve(CONTROL_PORT, logFile); 
                         while (!stopping)
                         {
                             Sleep(5000);
                             logItWt("worker thread");
                         }
                         SetEvent(stopServiceEvent);
                     });
    web.isDaemon = true;
    web.start();

    // running
    serviceStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP;
    auto runningStatus = SetStatus(SERVICE_RUNNING);
    debug logIt("runningStatus ", runningStatus);
}

void StopService()
{
    debug logIt("StopService called");
    serviceStatus.dwControlsAccepted = 0;
    SetStatus(SERVICE_STOP_PENDING);
    stopping = true; //tell worker thread to stop

    //wait for signal
    if (WaitForSingleObject(stopServiceEvent, INFINITE) != WAIT_OBJECT_0)
    {
        auto err = GetLastError();
        throw new Exception("Error: %s", to!string(err));
    }

    // service was stopped signaled and SERVICE_STOP_PENDING set already - so clean up
    CloseHandle(stopServiceEvent);
    stopServiceEvent = null;

    // service is now stopped
    auto stoppedStatus = SetStatus(SERVICE_STOPPED);
    debug logIt("stoppedStatus ", stoppedStatus);
}


// Set the service status and report the status to the SCM.
DWORD SetStatus(DWORD state, 
                DWORD exitCode = NO_ERROR, 
                DWORD waitHint = 0)
{
    serviceStatus.dwCheckPoint = ((state == SERVICE_RUNNING) || (state == SERVICE_STOPPED)) 
        ? 0 
        : checkPoint++;
    serviceStatus.dwCurrentState = state;
    serviceStatus.dwWin32ExitCode = exitCode;
    serviceStatus.dwWaitHint = waitHint;
    auto result = SetServiceStatus(serviceStatusHandle, &serviceStatus);
    if (result == 0) 
    {
        auto errCode = GetLastError();
        logIt("SetServiceStatus error ", errCode);
    }
    return result;
}


// ---------------------------------------------------------------------------

void RunService()
{
    serviceTable =
    [
        SERVICE_TABLE_ENTRY(serviceName, &ServiceMain),
        SERVICE_TABLE_ENTRY(null, null)
    ];

    debug logIt("RunService serviceTable.ptr ", serviceTable.ptr);
    StartServiceCtrlDispatcher(serviceTable.ptr);
}

void InstallService()
{
    SC_HANDLE serviceControlManager = OpenSCManager(null, null,
                                                    SC_MANAGER_CONNECT | SC_MANAGER_CREATE_SERVICE);
    if (serviceControlManager)
    {
        TCHAR path[_MAX_PATH + 1];
        if (GetModuleFileName(null, path.ptr, path.sizeof) > 0)
        {
            SC_HANDLE service = CreateService(
                                              serviceControlManager,
                                              cast (const) serviceName,
                                              cast (const) displayName,
                                              SERVICE_QUERY_STATUS,
                                              SERVICE_WIN32_OWN_PROCESS,
                                              SERVICE_AUTO_START, /*#define SERVICE_BOOT_START             0x00000000
                                              #define SERVICE_SYSTEM_START           0x00000001
                                              #define SERVICE_AUTO_START             0x00000002
                                              #define SERVICE_DEMAND_START           0x00000003
                                              #define SERVICE_DISABLED               0x00000004
                                              */
                                              SERVICE_ERROR_NORMAL,
                                              path.ptr,
                                              null, null, null, 
                                              cast (const) serviceStartName, 
                                              null);
            if (service)
                CloseServiceHandle(service);
        }

        CloseServiceHandle(serviceControlManager);
    }
}

void UninstallService()
{
    SC_HANDLE serviceControlManager = OpenSCManager(null, null,
                                                    SC_MANAGER_CONNECT);

    if (serviceControlManager)
    {
        SC_HANDLE service = OpenService(serviceControlManager,
                                        serviceName,
                                        SERVICE_QUERY_STATUS | DELETE);
        if (service)
        {
            SERVICE_STATUS serviceStatus;
            if (QueryServiceStatus(service, &serviceStatus))
            {
                if (serviceStatus.dwCurrentState == SERVICE_STOPPED)
                    DeleteService(service);
            }

            CloseServiceHandle(service);
        }

        CloseServiceHandle(serviceControlManager);
    }
}

void StartStop(bool toStart)
{
    debug logIt("StartStop");
    SC_HANDLE serviceControlManager = OpenSCManager(null, null,
                                                    SC_MANAGER_CONNECT);

    if (serviceControlManager)
    {
        SC_HANDLE service = OpenService(
                                        serviceControlManager,
                                        serviceName,
                                        SERVICE_QUERY_STATUS 
                                        | SERVICE_START 
                                        | SERVICE_STOP);

        if (service)
        {
            SERVICE_STATUS ss;
            uint result;

            if (toStart)
                result = StartService(service, 0, null);
            else
                result = ControlService(service, SERVICE_CONTROL_STOP, &ss);

            if (result == 0) {
                uint err = GetLastError();
                if (err == 1062)
                    writeln("Already stopped!");
                else if (err == 1056)
                    writeln("Already started!");
                else
                    writeln("Error: ", err);
            }

            CloseServiceHandle(service);
        }

        CloseServiceHandle(serviceControlManager);
    }
}

void main(string[] args)
{
    debug logIt("main ", args);
    initialize();
    if (args.length < 2)
    {
        writeln("running...");
        RunService();
    }
    else
    {
        switch (args[1])
        {
            case "install":
                writeln("installing...");
                InstallService();
                break;
            case "uninstall":
                writeln("uninstalling...");
                UninstallService();
                break;
            case "start":
                writeln("starting...");
                StartStop(true);
                break;
            case "stop":
                writeln("stopping...");
                StartStop(false);
                break;
            default:
                writefln("%s: unknown command: %s",
                         to!string(serviceName), args[1]);
                break;
        }
    }
}
