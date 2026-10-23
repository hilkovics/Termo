using System;
using System.Drawing;
using System.Text;

public static class HueStats {
    // Histogram of hue (10° bins) for saturated pixels, plus grey share, of a PNG.
    public static string Run(string png) {
        var bins = new long[36]; var satBins = new double[36]; var valBins = new double[36];
        long grey = 0, total = 0;
        using (var bmp = new Bitmap(png)) {
            for (int y = 0; y < bmp.Height; y += 2)
                for (int x = 0; x < bmp.Width; x += 2) {
                    var c = bmp.GetPixel(x, y);
                    if (c.A == 0) continue;
                    total++;
                    if (c.GetSaturation() < 0.25 || c.GetBrightness() < 0.08) { grey++; continue; }
                    int b = (int)(c.GetHue() / 10) % 36;
                    bins[b]++; satBins[b] += c.GetSaturation(); valBins[b] += c.GetBrightness();
                }
        }
        var sb = new StringBuilder();
        sb.AppendLine(string.Format("pixels {0}, grey/low-sat {1:P1}, coloured {2:P1}", total, (double)grey / total, 1 - (double)grey / total));
        for (int i = 0; i < 36; i++)
            if (bins[i] > total / 2000)
                sb.AppendLine(string.Format("  hue {0,3}-{1,3}: {2:P2} of all, avg sat {3:F2}, avg light {4:F2}", i * 10, i * 10 + 10, (double)bins[i] / total, satBins[i] / bins[i], valBins[i] / bins[i]));
        return sb.ToString();
    }
}
