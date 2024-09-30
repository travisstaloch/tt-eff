# find .ttf and .otf files in /usr and parse them.  print files, error and skip counts.

import subprocess
from subprocess import PIPE, Popen
import sys

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

result_ttf = subprocess.run(['find', '/usr', '-name', '*.ttf', '-print'], stdout=subprocess.PIPE).stdout
# result_ttf = ""
result_otf = subprocess.run(['find', '/usr', '-name', '*.otf', '-print'], stdout=subprocess.PIPE).stdout
files = result_ttf.split() + result_otf.split()

long_files=[
  b'/usr/share/ghostscript/9.55.0/Resource/CIDFSubst/DroidSansFallback.ttf',
  b'/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
]
files_with_errors=[
  b'/usr/share/wine/fonts/webdings.ttf',
  b'/usr/share/wine/fonts/wingding.ttf',
  b'/usr/share/wine/fonts/marlett.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-C.ttf',
  b'/usr/share/fonts/truetype/ubuntu/UbuntuMono-BI.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-M.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-L.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-RI.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf',
  b'/usr/share/fonts/truetype/ubuntu/UbuntuMono-RI.ttf',
  b'/usr/share/fonts/truetype/ubuntu/UbuntuMono-R.ttf',
  b'/usr/share/fonts/truetype/ubuntu/UbuntuMono-B.ttf',
  b'/usr/share/fonts/truetype/ubuntu/Ubuntu-BI.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Impact.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/couri.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/georgiab.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/georgia.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/cour.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/arialbd.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Arial.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Arial_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Arial_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Georgia_Bold.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/arialbi.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/webdings.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Courier_New_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/timesbi.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/georgiai.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Courier_New_Bold.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/ariali.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Trebuchet_MS.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/courbi.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Arial_Black.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/verdanai.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/andalemo.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Verdana_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Webdings.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Georgia.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Verdana_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/verdanaz.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/trebucbi.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Verdana.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/courbd.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/impact.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/verdana.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/verdanab.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Courier_New_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/trebuc.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/timesi.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/times.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/georgiaz.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Georgia_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/ariblk.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Verdana_Bold.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Andale_Mono.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Georgia_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/timesbd.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/Trebuchet_MS_Bold_Italic.ttf',
  b'/usr/share/fonts/truetype/msttcorefonts/arial.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerifDisplay-Regular.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerifMyanmar-Regular.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerifDisplay-Bold.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSansDisplay-Bold.ttf',
  b'/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerif-Bold.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSansDisplay-Regular.ttf',
  b'/usr/share/fonts/truetype/noto/NotoSerifMyanmar-Bold.ttf',
  b'/usr/share/fonts/truetype/freefont/FreeSans.ttf',
  b'/usr/share/fonts/truetype/freefont/FreeSerifBold.ttf',
  b'/usr/share/fonts/truetype/freefont/FreeSerif.ttf',
]

error_count = 0
for file in files:
  if file in long_files:
    continue
  files_to_skip = files_with_errors[0:3]
  if file in files_to_skip:
    continue
  args = ['zig',  'build',  'run', '-Doptimize=ReleaseSafe',  '--',  file]
  # args = ['zig',  'build',  'run', '-Doptimize=ReleaseFast',  '--',  file]
  # args = ['zig',  'build',  'run',  '--',  file]
  result = Popen(args, stdout=PIPE, stderr=PIPE)
  output, err = result.communicate()

  output = output.decode('utf-8')
  err = err.decode('utf-8')
  if result.returncode != 0:
    error_count += 1
    print(f"{file},")
    if "egfault" in err or "egfault" in output:
      print(output)
      print(err)
      break
  else:
    # print(file, err)
    pass

percent = len(files_to_skip) / len(files) * 100.0
errpercent = error_count / len(files) * 100.0

print(f"errors {error_count} / ({len(files)} {errpercent:.2f}%) skipped {len(files_to_skip)} / ({len(files)} {percent:.2f}%)")