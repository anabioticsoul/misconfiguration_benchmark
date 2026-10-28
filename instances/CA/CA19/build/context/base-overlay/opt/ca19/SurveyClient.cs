using System;
using System.Configuration;

namespace SurveyClient.Properties
{
    internal sealed class Settings : ApplicationSettingsBase
    {
        private static readonly Settings instance = (Settings)Synchronized(new Settings());
        public static Settings Default { get { return instance; } }

        [UserScopedSetting]
        [DefaultSettingValue("")]
        public string ApplicationData
        {
            get { return (string)this["ApplicationData"]; }
            set { this["ApplicationData"] = value; }
        }
    }
}

class Program
{
    static int Main()
    {
        Console.WriteLine("ApplicationData=" + SurveyClient.Properties.Settings.Default.ApplicationData);
        return 0;
    }
}
