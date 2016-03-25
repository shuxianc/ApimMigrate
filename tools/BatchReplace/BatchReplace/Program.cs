using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace BatchReplace
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length != 1)
            {
                throw new ArgumentException("Usage: BatchReplace {rootPath}");
            }
            var rootPath = args[0];
            var files = Directory.GetFiles(rootPath, "*.*", SearchOption.AllDirectories);
            var dirs = Directory.GetDirectories(rootPath, "*.*", SearchOption.AllDirectories);
            var mapping = new Dictionary<string, string>();

            using (var sr = new StreamReader("IDMapping.csv"))
            {
                var line = sr.ReadLine();
                while(line != null)
                {
                    var segs = line.Split(',');
                    if (segs.Length >= 2)
                    {
                        mapping.Add(segs[0], segs[1]);
                    }

                    line = sr.ReadLine();
                }

            }

            foreach (var f in files)
            {
                replaceIdinFile(f, mapping);
                replaceIdinFileName(f, mapping);
            }

            Array.Sort(dirs);
            dirs = dirs.Reverse().ToArray();
            foreach (var d in dirs)
            {
                replaceIdinDirName(d, mapping);
            }
        }
        static void replaceIdinFile(string filePath, Dictionary<string, string> mapping)
        {
            var content = File.ReadAllText(filePath);
            foreach (var kv in mapping)
            {
                content = content.Replace(kv.Value, kv.Key);
            }

            File.WriteAllText(filePath, content);
        }

        static void replaceIdinFileName(string filePath, Dictionary<string, string> mapping)
        {
            var segs = filePath.Split('\\');
            var fileName = segs.Last();
            foreach (var kv in mapping)
            {
                segs[segs.Length - 1] = fileName.Replace(kv.Value, kv.Key);
                fileName = segs.Last();
            }
            var newFileName = String.Join(@"\", segs);
            File.Move(filePath, newFileName);
        }

        static void replaceIdinDirName(string dirPath, Dictionary<string, string> mapping)
        {
            var segs = dirPath.Split('\\');

            var dirName = segs.Last();
            foreach (var kv in mapping)
            {
                segs[segs.Length - 1] = dirName.Replace(kv.Value, kv.Key);
                dirName = segs.Last();
            }

            var newDirPath = String.Join(@"\", segs);

            if (dirPath != newDirPath)
            {
                Directory.Move(dirPath, newDirPath);
            }
        }
    }

}
