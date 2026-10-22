using System;
using System.Reflection;

namespace DemoApp.Web
{
    public static class AppVersion
    {
        public static string Current
        {
            get
            {
                var attribute = (AssemblyInformationalVersionAttribute)Attribute.GetCustomAttribute(
                    typeof(AppVersion).Assembly,
                    typeof(AssemblyInformationalVersionAttribute));

                return attribute != null ? attribute.InformationalVersion : "unknown";
            }
        }
    }
}
