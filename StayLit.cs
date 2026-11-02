// StayLit - tiny tray app that prevents Windows from sleeping, turning off
// the display, or locking due to inactivity.
//
// How it works:
//  1. SetThreadExecutionState keeps the system and display awake.
//  2. Every 50 seconds it sends an invisible F15 key press, which resets the
//     idle timer (beats screensaver / policy-based idle locks).
//
// Build: build.bat   (uses the C# compiler that ships with Windows)

using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

static class StayLit
{
    [DllImport("kernel32.dll")]
    static extern uint SetThreadExecutionState(uint esFlags);

    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    static extern uint ExtractIconEx(string file, int index, IntPtr[] large, IntPtr[] small, uint count);

    const uint ES_CONTINUOUS       = 0x80000000;
    const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    const uint ES_DISPLAY_REQUIRED = 0x00000002;
    const byte VK_F15 = 0x7E;
    const uint KEYEVENTF_KEYUP = 0x0002;

    static bool active = true;
    static NotifyIcon tray;
    static Icon onIcon, offIcon;

    [STAThread]
    static void Main()
    {
        bool created;
        using (var mutex = new System.Threading.Mutex(true, "StayLit_SingleInstance", out created))
        {
            if (!created) return; // already running

            Application.EnableVisualStyles();
            var small = new IntPtr[1];
            ExtractIconEx(Application.ExecutablePath, 0, null, small, 1);
            onIcon = Icon.FromHandle(small[0]);
            offIcon = Greyscale(onIcon);

            var menu = new ContextMenuStrip();
            var toggle = new ToolStripMenuItem("Active", null, (s, e) => Toggle()) { Checked = true };
            menu.Items.Add(toggle);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, (s, e) => { tray.Visible = false; Application.Exit(); });

            tray = new NotifyIcon { ContextMenuStrip = menu, Visible = true };
            tray.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) Toggle(); };
            menu.Opening += (s, e) => toggle.Checked = active;

            var timer = new Timer { Interval = 50000 };
            timer.Tick += (s, e) => Ping();
            timer.Start();

            Apply();
            Application.Run();

            SetThreadExecutionState(ES_CONTINUOUS); // restore normal behaviour
        }
    }

    static void Toggle() { active = !active; Apply(); }

    static void Apply()
    {
        if (active)
            SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
        else
            SetThreadExecutionState(ES_CONTINUOUS);

        tray.Icon = active ? onIcon : offIcon;
        tray.Text = active ? "StayLit: ON (click to pause)" : "StayLit: OFF (click to resume)";
    }

    static void Ping()
    {
        if (!active) return;
        SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
        keybd_event(VK_F15, 0, 0, UIntPtr.Zero);
        keybd_event(VK_F15, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    // Dimmed greyscale copy of the icon for the paused state
    static Icon Greyscale(Icon src)
    {
        using (var color = src.ToBitmap())
        {
            var bmp = new Bitmap(color.Width, color.Height);
            var m = new System.Drawing.Imaging.ColorMatrix(new float[][] {
                new float[] { .3f, .3f, .3f, 0, 0 },
                new float[] { .59f, .59f, .59f, 0, 0 },
                new float[] { .11f, .11f, .11f, 0, 0 },
                new float[] { 0, 0, 0, .75f, 0 },
                new float[] { 0, 0, 0, 0, 1 } });
            using (var attr = new System.Drawing.Imaging.ImageAttributes())
            using (var g = Graphics.FromImage(bmp))
            {
                attr.SetColorMatrix(m);
                g.DrawImage(color, new Rectangle(0, 0, bmp.Width, bmp.Height),
                    0, 0, color.Width, color.Height, GraphicsUnit.Pixel, attr);
            }
            return Icon.FromHandle(bmp.GetHicon());
        }
    }
}
