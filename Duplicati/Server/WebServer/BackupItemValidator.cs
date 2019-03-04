using System;
using System.Linq;
using Duplicati.Server.Serialization.Interface;

namespace Duplicati.Server.WebServer
{
    public static class BackupItemValidator
    {
        public static string ValidateBackup(IBackup item, ISchedule schedule)
        {
            if (string.IsNullOrWhiteSpace(item.Name))
                return "Missing a name";

            if (string.IsNullOrWhiteSpace(item.TargetURL))
                return "Missing a target";

            if (item.Sources == null || item.Sources.Any(x => string.IsNullOrWhiteSpace(x)) || item.Sources.Length == 0)
                return "Invalid source list";

            var disabledEncryption = false;
            var passphrase = string.Empty;
            var gpgAsymmetricEncryption = false;
            if (item.Settings != null)
            {
                foreach (var s in item.Settings)

                    if (string.Equals(s.Name, "--no-encryption", StringComparison.OrdinalIgnoreCase))
                        disabledEncryption = string.IsNullOrWhiteSpace(s.Value) || Library.Utility.Utility.ParseBool(s.Value, false);
                    else if (string.Equals(s.Name, "passphrase", StringComparison.OrdinalIgnoreCase))
                        passphrase = s.Value;
                    else if (string.Equals(s.Name, "keep-versions", StringComparison.OrdinalIgnoreCase))
                    {
                        int i;
                        if (!int.TryParse(s.Value, out i) || i <= 0)
                            return "Retention value must be a positive integer";
                    }
                    else if (string.Equals(s.Name, "keep-time", StringComparison.OrdinalIgnoreCase))
                    {
                        try
                        {
                            var ts = Library.Utility.Timeparser.ParseTimeSpan(s.Value);
                            if (ts <= TimeSpan.FromMinutes(5))
                                return "Retention value must be more than 5 minutes";
                        }
                        catch
                        {
                            return "Retention value must be a valid timespan";
                        }
                    }
                    else if (string.Equals(s.Name, "dblock-size", StringComparison.OrdinalIgnoreCase))
                    {
                        try
                        {
                            var ds = Library.Utility.Sizeparser.ParseSize(s.Value);
                            if (ds < 1024 * 1024)
                                return "DBlock size must be at least 1MB";
                        }
                        catch
                        {
                            return "DBlock value must be a valid size string";
                        }
                    }
                    else if (string.Equals(s.Name, "--blocksize", StringComparison.OrdinalIgnoreCase))
                    {
                        try
                        {
                            var ds = Library.Utility.Sizeparser.ParseSize(s.Value);
                            if (ds < 1024 || ds > int.MaxValue)
                                return "The blocksize must be at least 1KB";
                        }
                        catch
                        {
                            return "The blocksize value must be a valid size string";
                        }
                    }
                    else if (string.Equals(s.Name, "--prefix", StringComparison.OrdinalIgnoreCase))
                    {
                        if (!string.IsNullOrWhiteSpace(s.Value) && s.Value.Contains("-"))
                            return "The prefix cannot contain hyphens (-)";
                    }
                    else if (string.Equals(s.Name, "--gpg-encryption-command", StringComparison.OrdinalIgnoreCase)) {
                        gpgAsymmetricEncryption = string.Equals(s.Value, "--encrypt", StringComparison.OrdinalIgnoreCase);
                    }
            }

            if (!disabledEncryption && !gpgAsymmetricEncryption && string.IsNullOrWhiteSpace(passphrase))
                return "Missing passphrase";

            if (schedule != null)
            {
                try
                {
                    var ts = Library.Utility.Timeparser.ParseTimeSpan(schedule.Repeat);
                    if (ts <= TimeSpan.FromMinutes(5))
                        return "Schedule repetition time must be more than 5 minutes";
                }
                catch
                {
                    return "Schedule repetition value must be a valid timespan";
                }

            }

            return null;
        }
    }
}
