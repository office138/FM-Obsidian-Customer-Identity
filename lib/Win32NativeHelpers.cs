// FM-Obsidian-Bridge Win32 Native Merge Helper
// Pre-compiled version of inline Add-Type C# from FM-Obsidian-Bridge-Payload.ps1
// Source lines: L1381-L1544 (Ver 9.1.1)
//
// This file is compiled to Win32NativeHelpers.dll by tools/Build-Win32Assembly.ps1
// and loaded at runtime via Add-Type -Path instead of Add-Type -TypeDefinition.

using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32NativeMergeHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "GetLongPathNameW")]
    public static extern uint GetLongPathName(
        string lpszShortPath,
        StringBuilder lpszLongPath,
        uint cchBuffer
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateDirectoryW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(
        string lpPathName,
        IntPtr lpSecurityAttributes
    );

    [StructLayout(LayoutKind.Sequential)]
    public struct BY_HANDLE_FILE_INFORMATION {
        public uint dwFileAttributes;
        public uint ftCreationTimeLow;
        public uint ftCreationTimeHigh;
        public uint ftLastAccessTimeLow;
        public uint ftLastAccessTimeHigh;
        public uint ftLastWriteTimeLow;
        public uint ftLastWriteTimeHigh;
        public uint dwVolumeSerialNumber;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint nNumberOfLinks;
        public uint nFileIndexHigh;
        public uint nFileIndexLow;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFileInformationByHandle(
        IntPtr hFile,
        out BY_HANDLE_FILE_INFORMATION lpFileInformation
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WIN32_FIND_STREAM_DATA {
        public long StreamSize;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 296)]
        public string cStreamName;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "FindFirstStreamW")]
    public static extern IntPtr FindFirstStream(
        string lpFileName,
        int InfoLevel,
        out WIN32_FIND_STREAM_DATA lpFindStreamData,
        uint dwFlags
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "FindNextStreamW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FindNextStream(
        IntPtr hFindStream,
        out WIN32_FIND_STREAM_DATA lpFindStreamData
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FindClose(IntPtr hFindFile);

    [StructLayout(LayoutKind.Sequential)]
    public struct FILE_CASE_SENSITIVE_INFO {
        public uint Flags;
    }

    public const int FileCaseSensitiveInfo = 23;
    public const uint FILE_CS_FLAG_CASE_SENSITIVE_DIR = 0x00000001;

    public const uint FILE_READ_ATTRIBUTES = 0x0080;
    public const uint FILE_SHARE_READ   = 0x00000001;
    public const uint FILE_SHARE_WRITE  = 0x00000002;
    public const uint FILE_SHARE_DELETE = 0x00000004;
    public const uint OPEN_EXISTING = 3;
    public const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateFileW")]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFileInformationByHandleEx(
        IntPtr hFile,
        int FileInformationClass,
        out FILE_CASE_SENSITIVE_INFO lpFileInformation,
        uint dwBufferSize
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FILE_RENAME_INFO {
        [MarshalAs(UnmanagedType.U1)]
        public bool ReplaceIfExists;
        public IntPtr RootDirectory;
        public uint FileNameLength;
        public char FileName;
    }

    public const uint DELETE = 0x00010000;
    public const uint FILE_LIST_DIRECTORY = 0x00000001;
    public const int FileRenameInfo = 3;
    public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetFileInformationByHandle(
        IntPtr hFile,
        int FileInformationClass,
        IntPtr lpFileInformation,
        uint dwBufferSize
    );

    public static bool RenameDirectory(IntPtr hFile, string newPath, bool replaceIfExists, out int win32Error)
    {
        win32Error = 0;
        string pathWithNull = newPath + "\0";
        byte[] nameBytes = Encoding.Unicode.GetBytes(pathWithNull);
        uint nameLenWithoutNull = (uint)Encoding.Unicode.GetByteCount(newPath);

        int offsetFileName = (IntPtr.Size == 8) ? 20 : 12;
        int offsetLen = (IntPtr.Size == 8) ? 16 : 8;

        int totalSize = offsetFileName + nameBytes.Length + 16;
        IntPtr pBuf = Marshal.AllocHGlobal(totalSize);

        try
        {
            for (int i = 0; i < totalSize; i++) Marshal.WriteByte(pBuf, i, 0);

            Marshal.WriteByte(pBuf, 0, (byte)(replaceIfExists ? 1 : 0));
            Marshal.WriteInt32(pBuf, offsetLen, (int)nameLenWithoutNull);
            Marshal.Copy(nameBytes, 0, new IntPtr(pBuf.ToInt64() + offsetFileName), nameBytes.Length);

            bool ok = SetFileInformationByHandle(hFile, FileRenameInfo, pBuf, (uint)(offsetFileName + nameBytes.Length));
            if (!ok)
            {
                win32Error = Marshal.GetLastWin32Error();
            }
            return ok;
        }
        finally
        {
            Marshal.FreeHGlobal(pBuf);
        }
    }
}

public static class Win32DurableJournalHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "MoveFileExW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(
        string lpExistingFileName,
        string lpNewFileName,
        uint dwFlags
    );

    public const uint MOVEFILE_REPLACE_EXISTING = 0x1;
    public const uint MOVEFILE_WRITE_THROUGH    = 0x8;
}
