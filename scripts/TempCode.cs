using System;
using System.IO;
using System.IO.Compression;
using System.Text;

public static class TempCode {
    // Prevedie farby termo snímky (paleta Hot Iron) na pozíciu v palete u ∈ [0, 1]:
    //   šedá časť   u = 0 … 0,5 podľa jasu (tmavá = najchladnejšie),
    //   farebná časť u = 0,5 … 1 podľa odtieňa (tmavočervená → žltá → žltozelená = najteplejšie).
    // Teplotu z u dopočíta mapa (22 – 35 °C, hranicu farby nastaví používateľ).
    static double U(byte r, byte g, byte b) {
        int max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
        double lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        double s = max == 0 ? 0 : (max - min) / (double)max;
        if (s < 0.25) return 0.5 * lum;
        double d = max - min, h;
        if (max == r) h = 60 * (((g - b) / d) % 6);
        else if (max == g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
        if (h < 0) h += 360;
        if (h >= 180 && h < 300) return 0.5 * lum; // fialové a modré nádychy z prelínania záberov
        double ha = h >= 300 ? h - 360 : h;
        double p = Math.Max(0, Math.Min(1, (ha + 20) / 120.0));
        return 0.5 + 0.5 * p;
    }

    // Číta dlaždicový RGBA8 TIFF (deflate, little-endian), priemeruje u po blokoch factor×factor
    // a zapíše binárny súbor: int32 šírka, int32 výška, int32 factor, potom bajty (0 = bez dát, 1–255 = u).
    public static string Run(string path, int factor, string outBin) {
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
            int tx = (W + TW - 1) / TW;
            int ow = (W + factor - 1) / factor, oh = (H + factor - 1) / factor;
            var sum = new double[ow * oh];
            var num = new int[ow * oh];
            var tile = new byte[TW * TH * 4];
            for (int t = 0; t < offs.Length; t++) {
                if (cnts[t] == 0) continue;
                fs.Position = offs[t] + 2; // preskočí zlib hlavičku
                var comp = br.ReadBytes((int)cnts[t] - 2);
                using (var ds = new DeflateStream(new MemoryStream(comp), CompressionMode.Decompress)) {
                    int read = 0, r;
                    while (read < tile.Length && (r = ds.Read(tile, read, tile.Length - read)) > 0) read += r;
                }
                int x0 = (t % tx) * TW, y0 = (t / tx) * TH;
                for (int y = 0; y < TH; y++) {
                    int gy = y0 + y; if (gy >= H) break;
                    int rowBase = (gy / factor) * ow;
                    for (int x = 0; x < TW; x++) {
                        int gx = x0 + x; if (gx >= W) break;
                        int p = (y * TW + x) * 4;
                        if (tile[p + 3] == 0) continue;
                        int o = rowBase + gx / factor;
                        sum[o] += U(tile[p], tile[p + 1], tile[p + 2]);
                        num[o]++;
                    }
                }
            }
            var hist = new long[256];
            using (var os = File.Create(outBin)) {
                var bw = new BinaryWriter(os);
                bw.Write(ow); bw.Write(oh); bw.Write(factor);
                for (int o = 0; o < ow * oh; o++) {
                    byte c = num[o] == 0 ? (byte)0 : (byte)(1 + (int)Math.Round(254 * sum[o] / num[o]));
                    hist[c]++;
                    bw.Write(c);
                }
            }
            long data = 0, colour = 0;
            for (int c = 1; c < 256; c++) { data += hist[c]; if (c > 128) colour += hist[c]; }
            sb.AppendLine(string.Format("grid {0}x{1} (factor {2}), cells with data {3}, coloured part {4:P1}", ow, oh, factor, data, (double)colour / data));
        }
        return sb.ToString();
    }
}
