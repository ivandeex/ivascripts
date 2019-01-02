#!/usr/bin/env python3
import os
import sys
import base64
if len(sys.argv) != 2 or sys.argv[1] not in ['-md5', '-sha1', 'md5.txt', 'sha1.txt']:
  sys.exit('usage: {} -md5 | -sha1 < sum.txt > sum.xml'.format(os.path.basename(sys.argv[0])))
if sys.argv[1].endswith('.txt'):
  tag = sys.argv[1].split('.')[0]
  sys.stdin = open('%s.txt' % tag)
  sys.stdout = open('%s.xml' % tag, 'w')
else:
  tag = sys.argv[1][1:]
tag = tag.upper()
print('<?xml version="1.0" encoding="utf-8"?>')
print('<FCIV>')
for line in sys.stdin:
  if line.startswith('#') or not line.strip():
    continue
  as_hex, name = line.split()
  as_base64 = base64.b64encode(bytes.fromhex(as_hex)).decode('ascii')
  name = name.replace('/', '\\')
  print('<FILE_ENTRY><name>{}</name><{}>{}</{}></FILE_ENTRY>'.format(name, tag, as_base64, tag))
print('</FCIV>')
