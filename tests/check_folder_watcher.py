import os, subprocess, tempfile, pathlib, selectors, time
with tempfile.TemporaryDirectory() as temp:
 root=pathlib.Path(temp); files=root/'files';files.mkdir();(files/'subfolder').mkdir();(files/'a.pdf').write_text('pdf');(files/'hidden.txt').write_text('txt')
 qml=root/'test.qml'
 qml.write_text('''import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
Window {
 width: 100; height: 100; visible: true
 FolderListModel { id: model; folder: "'''+files.as_uri()+'''"; nameFilters: ["*.pdf"]; showDirs: true; showDirsFirst: true; showDotAndDotDot: false }
 Timer { interval: 200; running: true; repeat: true; onTriggered: console.warn("COUNT="+model.count) }
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_FORCE_STDERR_LOGGING='1')
 p=subprocess.Popen(['qml-qt6',str(qml)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
 sel=selectors.DefaultSelector();sel.register(p.stdout,selectors.EVENT_READ)
 def wait_count(wanted):
  deadline=time.monotonic()+15;lines=[]
  while time.monotonic()<deadline:
   for key,event in sel.select(.2):
    line=key.fileobj.readline();lines.append(line)
    if 'COUNT='+str(wanted) in line: return
    if not line and p.poll() is not None: raise AssertionError('Exited: '+''.join(lines))
  raise AssertionError('Count '+str(wanted)+' not reached: '+''.join(lines))
 try:
  wait_count(2)
  (files/'b.pdf').write_text('pdf');wait_count(3)
  (files/'a.pdf').unlink();wait_count(2)
  print('PASS: Qt folder model preserves subfolders under a file mask and updates after add/remove')
 finally:
  p.terminate()
  try:p.wait(timeout=3)
  except subprocess.TimeoutExpired:p.kill();p.wait()
