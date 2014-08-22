import std.stdio;
import winsvc.installer;
import winsvc.svcbase;
import mysvc;

int main(string[] argv)
{
    string serviceName = "MyTestSvc"; 
    string displayName = "My Test Service"; 
    bool autoStart = false; 
    string cmdLineArgs = null; 
    string account = "NT AUTHORITY\\NetworkService";
    string password = null;

    if (argv.length < 2)
    {
        auto service = new MyService(serviceName, displayName);
        ServiceBase.Run(service);
    }
    else if (argv[1] == "install")
    {
        writeln("installing service");
        if (InstallService(serviceName, displayName, autoStart, cmdLineArgs, account, password))
            writeln("service installed");
        else
            writeln("service NOT installed");
    }
    else if (argv[1] == "uninstall")
    {
        writeln("uninstalling service");
        if (UninstallService(serviceName))
            writeln("service uninstalled");
        else
            writeln("service NOT uninstalled");
    }
    else
    {
        writeln("usage: onedge {install|uninstall}");
    }
    return 0;
}
