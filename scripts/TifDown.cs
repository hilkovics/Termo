using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Text;

public static class TifDown {
    // Reads a little-endian tiled RGBA8 deflate TIFF, box-averages it by `factor`
    // into a PNG and returns colour statistics of the image.
    public static string Run(string path, int factor, string outPng) {
        var sb = new StringBuilder();
        using (var fs = File.OpenRead(path)) {
            var br = new BinaryReader(fs);
            fs.Position = 4;
            fs.Position = br.ReadUInt32();
            int n = br.ReadUInt16();
            int W = 0, H = 0, TW = 0, TH = 0;
            long[] offs = null, cnts = null;
            for (int i = 0; i < n; i++) {
                ushort tag = br.ReadUInt16(); ushort type = br.ReadUInt16();
                uint count = br.ReadUInt32(); uint val = br.ReadUInt32();
                long save = fs.Position;
                if (tag == 256) W = (int)val;
                else if (tag == 257) H = (int)val;
                else if (tag == 322) TW = (int)val;
                else if (tag == 323) TH = (int)val;
                else if (tag == 324 || tag == 325) {
                    var arr = new long[count];
                    fs.Position = val;
                    for (int k = 0; k < count; k++) arr[k] = type == 16 ? (long)br.ReadUInt64() : br.ReadUInt32();
                    if (tag == 324) offs = arr; else cnts = arr;
                    fs.Position = save;
                }
            }
            int tx = (W + TW - 1) / TW, ty = (H + TH - 1) / TH;
            int ow = W / factor, oh = H / factor;
            var sum = new int[ow * oh * 3];
            var num = new int[ow * oh];
            var tile = new byte[TW * TH * 4];
            var hist = new Dictionary<int, long>();
            long opaque = 0, gray = 0;
            for (int t = 0; t < offs.Length; t++) {
                if (cnts[t] == 0) continue;
                fs.Position = offs[t] + 2; // skip zlib header
                var comp = br.ReadBytes((int)cnts[t] - 2);
                using (var ds = new DeflateStream(new MemoryStream(comp), CompressionMode.Decompress)) {
                    int read = 0, r;
                    while (read < tile.Length && (r = ds.Read(tile, read, tile.Length - read)) > 0) read += r;
                }
                int x0 = (t % tx) * TW, y0 = (t / tx) * TH;
                for (int y = 0; y < TH; y++) {
                    int gy = y0 + y; if (gy >= oh * factor) break;
                    int oy = gy / factor;
                    for (int x = 0; x < TW; x++) {
                        int gx = x0 + x; if (gx >= ow * factor) break;
                        int p = (y * TW + x) * 4;
                        if (tile[p + 3] == 0) continue;
                        int o = oy * ow + gx / factor;
                        sum[o * 3] += tile[p]; sum[o * 3 + 1] += tile[p + 1]; sum[o * 3 + 2] += tile[p + 2];
                        num[o]++;
                        if ((gx & 7) == 0 && (gy & 7) == 0) {
                            opaque++;
                            if (tile[p] == tile[p + 1] && tile[p + 1] == tile[p + 2]) gray++;
                            int key = (tile[p] << 16) | (tile[p + 1] << 8) | tile[p + 2];
                            long c; hist.TryGetValue(key, out c); hist[key] = c + 1;
                        }
                    }
                }
            }
            var px = new byte[ow * oh * 4];
            for (int o = 0; o < ow * oh; o++) {
                if (num[o] == 0) continue;
                px[o * 4 + 2] = (byte)(sum[o * 3] / num[o]);
                px[o * 4 + 1] = (byte)(sum[o * 3 + 1] / num[o]);
                px[o * 4] = (byte)(sum[o * 3 + 2] / num[o]);
                px[o * 4 + 3] = 255;
            }
            using (var bmp = new Bitmap(ow, oh, PixelFormat.Format32bppArgb)) {
                var bd = bmp.LockBits(new Rectangle(0, 0, ow, oh), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                for (int y = 0; y < oh; y++) Marshal.Copy(px, y * ow * 4, bd.Scan0 + y * bd.Stride, ow * 4);
                bmp.UnlockBits(bd);
                bmp.Save(outPng, ImageFormat.Png);
            }
            sb.AppendLine(string.Format("image {0}x{1}, tiles {2}x{3}, out {4}x{5}", W, H, tx, ty, ow, oh));
            sb.AppendLine(string.Format("sampled opaque px {0}, gray (R=G=B) {1:P1}, unique colours {2}", opaque, opaque == 0 ? 0 : (double)gray / opaque, hist.Count));
            var list = new List<KeyValuePair<int, long>>(hist);
            list.Sort((a, b) => b.Value.CompareTo(a.Value));
            for (int i = 0; i < Math.Min(40, list.Count); i++) {
                int k = list[i].Key;
                sb.AppendLine(string.Format("  #{0:x6} {1,8} ({2:P2})", k, list[i].Value, (double)list[i].Value / opaque));
            }
        }
        return sb.ToString();
    }
}
