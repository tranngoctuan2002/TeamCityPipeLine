using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("DemoApp.Web")]
[assembly: AssemblyProduct("CI/CD Demo")]
[assembly: ComVisible(false)]
[assembly: Guid("2f6c1b7e-5a3d-4e8b-9c1f-7a2d4e6b8c10")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

// The improved pipeline replaces this value with the TeamCity build number (scripts/build.ps1 -Version).
// The current pipeline does not, so its site always shows "local-dev": no traceability.
[assembly: AssemblyInformationalVersion("local-dev")]
