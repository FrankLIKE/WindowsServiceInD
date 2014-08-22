module winsvc.installer;
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


enum _MAX_PATH = 4096;


bool InstallService(string serviceName, 
                    string displayName, 
                    bool autoStart,
                    string cmdLineArgs, 
                    string account, 
                    string password)
{
    bool result;
    SC_HANDLE svcControlManager = OpenSCManager(null, null,
                                                SC_MANAGER_CONNECT | SC_MANAGER_CREATE_SERVICE);
    if (svcControlManager)
    {
        TCHAR path[_MAX_PATH + 1];
        if (GetModuleFileName(null, path.ptr, path.sizeof) > 0)
        {
            if (null != cmdLineArgs && cmdLineArgs.length > 0)
            {
                string combinedPath = to!string(path) ~ " " ~ cmdLineArgs;
                path = cast (char[]) combinedPath;
            }
            DWORD serviceStart = autoStart ? SERVICE_AUTO_START : SERVICE_DEMAND_START;
            SC_HANDLE service = CreateService(svcControlManager,
                                              cast (const) cast (char*) toStringz(serviceName),
                                              cast (const) cast (char*) toStringz(displayName),
                                              SERVICE_QUERY_STATUS,
                                              SERVICE_WIN32_OWN_PROCESS,
                                              serviceStart,
                                              SERVICE_ERROR_NORMAL,
                                              path.ptr,
                                              null, 
                                              null, 
                                              null, 
                                              account == null 
                                                ? null 
                                                : cast (const) cast (char*) toStringz(account), 
                                              password == null 
                                                ? null 
                                                : cast (const) cast (char*) toStringz(password));
            if (service) 
            {
                CloseServiceHandle(service);
                result = true;
            }
        }
        CloseServiceHandle(svcControlManager);
    }
    return result;
}

bool UninstallService(string serviceName)
{
    bool result;
    SC_HANDLE svcControlManager = OpenSCManager(null, null,
                                                    SC_MANAGER_CONNECT);
    if (svcControlManager)
    {
        SC_HANDLE service = OpenService(svcControlManager,
                                        cast (const) cast (char*) toStringz(serviceName),
                                        SERVICE_QUERY_STATUS | DELETE);
        if (service)
        {
            SERVICE_STATUS serviceStatus;
            if (QueryServiceStatus(service, &serviceStatus))
            {
                try
                {
                    if (serviceStatus.dwCurrentState == SERVICE_STOPPED)
                    {
                        result = cast (bool) DeleteService(service);
                    }
                }
                catch (Exception)
                {
                    result = false;
                }
            }

            CloseServiceHandle(service);
        }
        CloseServiceHandle(svcControlManager);
    }
    return result;
}
