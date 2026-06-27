$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$enhancerSource = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class IhamImageEnhancer
{
    private static byte Clamp(double value)
    {
        if (value < 0) return 0;
        if (value > 255) return 255;
        return (byte)Math.Round(value);
    }

    public static void Enhance(string sourcePath, string destinationPath)
    {
        using (var source = Image.FromFile(sourcePath))
        {
            int width = source.Width;
            int height = source.Height;

            using (var normalized = new Bitmap(width, height, PixelFormat.Format24bppRgb))
            {
                normalized.SetResolution(source.HorizontalResolution, source.VerticalResolution);
                using (var graphics = Graphics.FromImage(normalized))
                {
                    graphics.Clear(Color.White);
                    graphics.CompositingQuality = CompositingQuality.HighQuality;
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.SmoothingMode = SmoothingMode.HighQuality;
                    graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    graphics.DrawImage(source, 0, 0, width, height);
                }

                var bounds = new Rectangle(0, 0, width, height);
                var data = normalized.LockBits(bounds, ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
                int stride = data.Stride;
                int bytes = Math.Abs(stride) * height;
                byte[] original = new byte[bytes];
                byte[] adjusted = new byte[bytes];
                byte[] output = new byte[bytes];

                Marshal.Copy(data.Scan0, original, 0, bytes);

                const double saturation = 1.08;
                const double contrast = 1.07;
                const double brightness = 5.0;

                for (int y = 0; y < height; y++)
                {
                    int row = y * stride;
                    for (int x = 0; x < width; x++)
                    {
                        int offset = row + x * 3;
                        double b = original[offset];
                        double g = original[offset + 1];
                        double r = original[offset + 2];
                        double luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;

                        r = ((luma + (r - luma) * saturation) - 128.0) * contrast + 128.0 + brightness;
                        g = ((luma + (g - luma) * saturation) - 128.0) * contrast + 128.0 + brightness;
                        b = ((luma + (b - luma) * saturation) - 128.0) * contrast + 128.0 + brightness;

                        adjusted[offset] = Clamp(b);
                        adjusted[offset + 1] = Clamp(g);
                        adjusted[offset + 2] = Clamp(r);
                    }
                }

                Buffer.BlockCopy(adjusted, 0, output, 0, adjusted.Length);

                const double amount = 0.14;
                double center = 1.0 + 4.0 * amount;

                for (int y = 1; y < height - 1; y++)
                {
                    int row = y * stride;
                    int up = (y - 1) * stride;
                    int down = (y + 1) * stride;
                    for (int x = 1; x < width - 1; x++)
                    {
                        int offset = row + x * 3;
                        int left = row + (x - 1) * 3;
                        int right = row + (x + 1) * 3;
                        int north = up + x * 3;
                        int south = down + x * 3;

                        for (int c = 0; c < 3; c++)
                        {
                            double value =
                                adjusted[offset + c] * center -
                                amount * (adjusted[left + c] + adjusted[right + c] + adjusted[north + c] + adjusted[south + c]);
                            output[offset + c] = Clamp(value);
                        }
                    }
                }

                Marshal.Copy(output, 0, data.Scan0, bytes);
                normalized.UnlockBits(data);

                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                var codec = GetJpegCodec();
                using (var parameters = new EncoderParameters(1))
                {
                    parameters.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 92L);
                    normalized.Save(destinationPath, codec, parameters);
                }
            }
        }
    }

    private static ImageCodecInfo GetJpegCodec()
    {
        foreach (var codec in ImageCodecInfo.GetImageEncoders())
        {
            if (codec.MimeType == "image/jpeg") return codec;
        }
        throw new InvalidOperationException("JPEG encoder not found.");
    }
}
"@

Add-Type -TypeDefinition $enhancerSource -ReferencedAssemblies "System.Drawing"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceDir = Join-Path $root "images iham"
$destinationDir = Join-Path $root "assets\images\iham-story"

$images = @(
    @{ Source = "WhatsApp Image 2026-06-28 at 12.20.06 AM (1).jpeg"; Target = "01-black-fit.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.20.06 AM (2).jpeg"; Target = "02-drive-close.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.20.06 AM (3).jpeg"; Target = "03-training-day.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.20.06 AM (5).jpeg"; Target = "04-cafe-jersey.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.07 AM.jpeg"; Target = "05-road-trip.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.08 AM (1).jpeg"; Target = "06-blue-dining.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.08 AM (2).jpeg"; Target = "07-friends-outing.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.08 AM (3).jpeg"; Target = "08-evening-walk.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.08 AM (4).jpeg"; Target = "09-gems-graduation.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.08 AM.jpeg"; Target = "10-map-lounge.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.09 AM (1).jpeg"; Target = "11-beach-day.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.09 AM (2).jpeg"; Target = "12-dinner-drinks.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.09 AM (3).jpeg"; Target = "13-sunset-coast.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.09 AM (4).jpeg"; Target = "14-night-terrace.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.09 AM.jpeg"; Target = "15-hotel-room.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.10 AM (1).jpeg"; Target = "16-coastal-travel.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.10 AM (2).jpeg"; Target = "17-lounge-night.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.10 AM (3).jpeg"; Target = "18-sports-cafe.jpeg" },
    @{ Source = "WhatsApp Image 2026-06-28 at 12.41.10 AM.jpeg"; Target = "19-dinner-night.jpeg" }
)

New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

foreach ($image in $images) {
    $source = Join-Path $sourceDir $image.Source
    $destination = Join-Path $destinationDir $image.Target

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing source image: $source"
    }

    [IhamImageEnhancer]::Enhance($source, $destination)
    Write-Output $image.Target
}
