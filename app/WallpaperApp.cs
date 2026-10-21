using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
[assembly:System.Reflection.AssemblyTitle("Codex 壁纸设置")]
[assembly:System.Reflection.AssemblyDescription("Local wallpaper settings for Codex")]
[assembly:System.Reflection.AssemblyVersion("1.0.0.0")]

namespace CodexWallpaper {
  public sealed class WallpaperSettings {
    public bool enabled {get;set;}
    public string imagePath {get;set;}
    public double brightness {get;set;}
    public double blur {get;set;}
    public double tint {get;set;}
    public string scope {get;set;}
    public WallpaperSettings() {brightness=1;tint=.36;scope="window";}
  }
  public sealed class LiveStatus {
    public string state {get;set;}
    public string time {get;set;}
    public int pid {get;set;}
    public bool mainReady {get;set;}
    public bool running {get;set;}
    public bool applied {get;set;}
    public string settingsHash {get;set;}
    public string message {get;set;}
  }
  public sealed class WallpaperState {
    public WallpaperSettings settings {get;set;}
    public LiveStatus live {get;set;}
  }
  public sealed class WallpaperController {
    public string Root {get;private set;}
    public WallpaperController(string root) {Root=Path.GetFullPath(root);}
    internal static string ReadText(string file) {
      using(var stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
      using(var reader=new StreamReader(stream,Encoding.UTF8,true)) return reader.ReadToEnd();
    }
    public WallpaperState Read() {
      var json=new JavaScriptSerializer();
      var state=new WallpaperState {settings=new WallpaperSettings(),live=new LiveStatus {state="closed"}};
      string config=Path.Combine(Root,"settings.json");
      string raw=null;
      if(File.Exists(config)) {raw=ReadText(config);state.settings=json.Deserialize<WallpaperSettings>(raw);}
      try { state.live=json.Deserialize<LiveStatus>(ReadText(Path.Combine(Root,"live-status.json")))??state.live; } catch(IOException) {} catch(ArgumentException) {}
      DateTimeOffset time;
      bool fresh=DateTimeOffset.TryParse(state.live.time,CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal,out time)&&(DateTimeOffset.UtcNow-time).TotalSeconds>=-5&&(DateTimeOffset.UtcNow-time).TotalSeconds<6;
      bool alive=false;
      if(fresh&&state.live.pid>0) try {using(var process=Process.GetProcessById(state.live.pid)) alive=!process.HasExited;} catch(ArgumentException) {} catch(InvalidOperationException) {}
      state.live.running=alive&&state.live.state!="failed"&&state.live.state!="closed";
      string expectedHash=null;using(var hash=SHA256.Create()) if(raw!=null) expectedHash=BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(raw))).Replace("-","").ToLowerInvariant();
      state.live.applied=state.live.running&&state.live.mainReady&&(state.live.state=="active"||state.live.state=="disabled")&&expectedHash!=null&&state.live.settingsHash==expectedHash;
      return state;
    }
    public Task<WallpaperState> ApplyAsync(Dictionary<string,object> change) {
      return Task.Run(delegate {
        string node=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"nodejs","node.exe");
        if(!File.Exists(node)) node="node.exe";
        var start=new ProcessStartInfo(node,Quote(Path.Combine(Root,"scripts","control.cjs"))+" apply --root "+Quote(Root));
        start.WorkingDirectory=Root;start.UseShellExecute=false;start.CreateNoWindow=true;
        start.RedirectStandardInput=true;start.RedirectStandardOutput=true;start.RedirectStandardError=true;
        start.StandardOutputEncoding=Encoding.UTF8;start.StandardErrorEncoding=Encoding.UTF8;
        using(var process=new Process {StartInfo=start}) {
          process.Start();
          Task<string> output=process.StandardOutput.ReadToEndAsync(),error=process.StandardError.ReadToEndAsync();
          byte[] input=new UTF8Encoding(false).GetBytes(new JavaScriptSerializer().Serialize(change));
          process.StandardInput.BaseStream.Write(input,0,input.Length);process.StandardInput.BaseStream.Close();
          if(!process.WaitForExit(12000)) {process.Kill();throw new IOException("保存设置超时，请重试。");}
          string outText=output.GetAwaiter().GetResult(),errText=error.GetAwaiter().GetResult();
          if(process.ExitCode!=0) {
            string message=errText.Trim();
            try {var detail=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(message);message=Convert.ToString(detail["error"]);} catch {}
            throw new IOException(message.Length>0?message:"无法保存壁纸设置。");
          }
          return new JavaScriptSerializer().Deserialize<WallpaperState>(outText);
        }
      });
    }
    public void StartLoader() {
      string script=Path.Combine(Root,"scripts","launch-live-wallpaper.ps1");
      if(!File.Exists(script)) throw new FileNotFoundException("找不到壁纸启动器，请保留整个软件文件夹。",script);
      string command="& '"+script.Replace("'","''")+"'";
      string encoded=Convert.ToBase64String(Encoding.Unicode.GetBytes(command));
      var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe"),"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand "+encoded);
      info.WorkingDirectory=Root;info.UseShellExecute=false;info.CreateNoWindow=true;
      using(var process=Process.Start(info)) {}
    }
    internal static string Quote(string value) {
      var result=new StringBuilder("\"");int slashes=0;
      foreach(char ch in value) {
        if(ch=='\\') {slashes++;continue;}
        if(ch=='\"') {result.Append('\\',slashes*2+1);result.Append(ch);slashes=0;continue;}
        result.Append('\\',slashes);slashes=0;result.Append(ch);
      }
      result.Append('\\',slashes*2);return result.Append('"').ToString();
    }
  }
  internal static class Drawing {
    internal static GraphicsPath Round(RectangleF rectangle,float radius) {
      var path=new GraphicsPath();float d=radius*2;
      path.AddArc(rectangle.X,rectangle.Y,d,d,180,90);path.AddArc(rectangle.Right-d,rectangle.Y,d,d,270,90);
      path.AddArc(rectangle.Right-d,rectangle.Bottom-d,d,d,0,90);path.AddArc(rectangle.X,rectangle.Bottom-d,d,d,90,90);path.CloseFigure();return path;
    }
    internal static void FillRound(Graphics g,Color color,RectangleF rect,float radius) {using(var p=Round(rect,radius)) using(var brush=new SolidBrush(color)) g.FillPath(brush,p);}
  }
  internal sealed class PreviewCanvas : Control {
    private Bitmap image;private string loadedPath;private DateTime loadedTime;
    internal WallpaperSettings Settings=new WallpaperSettings();
    internal PreviewCanvas() {DoubleBuffered=true;BackColor=Color.White;}
    internal void UpdateImage(WallpaperSettings settings) {
      Settings=settings;DateTime stamp=File.Exists(settings.imagePath)?File.GetLastWriteTimeUtc(settings.imagePath):DateTime.MinValue;
      if(loadedPath!=settings.imagePath||loadedTime!=stamp) {
        if(image!=null) {image.Dispose();image=null;}
        loadedPath=settings.imagePath;loadedTime=stamp;
        try {using(var stream=new MemoryStream(File.ReadAllBytes(loadedPath))) using(var source=Image.FromStream(stream)) image=new Bitmap(source);} catch {}
      }
      Invalidate();
    }
    protected override void Dispose(bool disposing) {if(disposing&&image!=null) image.Dispose();base.Dispose(disposing);}
    protected override void OnPaint(PaintEventArgs e) {
      base.OnPaint(e);Graphics g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
      Rectangle area=new Rectangle(0,0,Width-1,Height-1);
      using(var clip=Drawing.Round(area,16)) {
        g.SetClip(clip);g.Clear(Color.FromArgb(226,231,241));
        if(image!=null) {
          double scale=Math.Max((double)Width/image.Width,(double)Height/image.Height);
          int sw=(int)(Width/scale),sh=(int)(Height/scale);var source=new Rectangle((image.Width-sw)/2,(image.Height-sh)/2,sw,sh);
          int smallWidth=Math.Max(24,(int)(Width/(1+Settings.blur*.55))),smallHeight=Math.Max(24,(int)(Height/(1+Settings.blur*.55)));
          using(var layer=new Bitmap(smallWidth,smallHeight)) {
            using(var lg=Graphics.FromImage(layer)) using(var attr=new ImageAttributes()) {
              float b=(float)Settings.brightness;var matrix=new ColorMatrix(new float[][] {new[]{b,0f,0f,0f,0f},new[]{0f,b,0f,0f,0f},new[]{0f,0f,b,0f,0f},new[]{0f,0f,0f,1f,0f},new[]{0f,0f,0f,0f,1f}});
              attr.SetColorMatrix(matrix);lg.DrawImage(image,new Rectangle(0,0,smallWidth,smallHeight),source.X,source.Y,source.Width,source.Height,GraphicsUnit.Pixel,attr);
            }
            g.InterpolationMode=InterpolationMode.HighQualityBilinear;g.DrawImage(layer,area);
          }
          using(var brush=new SolidBrush(Color.FromArgb((int)(Settings.tint*255),255,255,255))) g.FillRectangle(brush,area);
          Drawing.FillRound(g,Color.FromArgb(100,255,255,255),new RectangleF(12,12,Width-24,32),10);
          Drawing.FillRound(g,Color.FromArgb(105,255,255,255),new RectangleF(12,54,92,Height-66),10);
          Drawing.FillRound(g,Color.FromArgb(172,255,255,255),new RectangleF(118,Height-78,Width-132,64),14);
          using(var font=new Font("Microsoft YaHei UI",8f)) using(var brush=new SolidBrush(Color.FromArgb(60,70,90))) {
            g.DrawString("Codex",font,brush,24,20);g.DrawString("新聊天",font,brush,26,72);g.DrawString("项目",font,brush,26,112);g.DrawString("输入消息…",font,brush,132,Height-64);
          }
        } else {
          string message=String.IsNullOrWhiteSpace(Settings.imagePath)?"选择一张喜欢的图片":"此图片暂不能预览，仍可尝试应用";
          TextRenderer.DrawText(g,message,Font,area,Color.FromArgb(100,110,130),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
        }
        if(!Settings.enabled) {
          using(var brush=new SolidBrush(Color.FromArgb(180,245,247,251))) g.FillRectangle(brush,area);
          using(var font=new Font("Microsoft YaHei UI",13f)) TextRenderer.DrawText(g,"壁纸已关闭",font,area,Color.FromArgb(70,80,100),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
        }
        g.ResetClip();
      }
    }
  }
  public sealed class SettingsForm : Form {
    readonly WallpaperController controller;
    WallpaperSettings settings;
    readonly Dictionary<string,object> pending=new Dictionary<string,object>();
    bool loading,busy,launching,closeRequested;
    Task saveTask;
    readonly System.Windows.Forms.Timer applyTimer=new System.Windows.Forms.Timer {Interval=450};
    readonly System.Windows.Forms.Timer statusTimer=new System.Windows.Forms.Timer {Interval=1200};
    internal TrackBar BrightnessSlider,BlurSlider,TransparencySlider;
    readonly Label brightnessValue=new Label(),blurValue=new Label(),transparencyValue=new Label();
    readonly PreviewCanvas preview=new PreviewCanvas();
    readonly TextBox imagePath=new TextBox();
    readonly ComboBox scope=new ComboBox();
    readonly CheckBox enabled=new CheckBox();
    readonly Label statusLabel=new Label(),hintLabel=new Label();
    readonly Button startButton=new Button();
    public string LastError {get;private set;}
    readonly Color ink=Color.FromArgb(31,42,62),muted=Color.FromArgb(110,121,140),accent=Color.FromArgb(70,91,225);
    public SettingsForm(string root) {
      controller=new WallpaperController(root);Text="Codex 壁纸设置";Font=new Font("Microsoft YaHei UI",9f);
      ClientSize=new Size(1000,666);MinimumSize=Size;MaximumSize=Size;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;
      BackColor=Color.FromArgb(246,248,252);ForeColor=ink;AutoScaleMode=AutoScaleMode.Dpi;
      try {Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);} catch {}
      BuildUI();ReloadSettings();
      applyTimer.Tick+=async delegate {applyTimer.Stop();await ApplyPendingAsync();};
      statusTimer.Tick+=delegate {if(!busy&&!launching&&pending.Count==0) ReloadSettings();else RefreshStatus();};
      Shown+=delegate {statusTimer.Start();};
      FormClosing+=delegate(object sender,FormClosingEventArgs e) {
        if(busy||pending.Count>0) {e.Cancel=true;closeRequested=true;applyTimer.Stop();SaveThenClose();}
      };
    }
    async void SaveThenClose() {
      await ApplyPendingAsync();
    }
    protected override void Dispose(bool disposing) {if(disposing) {applyTimer.Dispose();statusTimer.Dispose();}base.Dispose(disposing);}
    Label LabelAt(string text,int x,int y,int width,int height,float size,Color color) {
      return new Label {Text=text,Location=new Point(x,y),Size=new Size(width,height),Font=new Font("Microsoft YaHei UI",size),ForeColor=color,BackColor=Color.Transparent};
    }
    Button ButtonAt(string text,int x,int y,int width,int height,bool primary) {
      var button=new Button {Text=text,Location=new Point(x,y),Size=new Size(width,height),FlatStyle=FlatStyle.Flat,Cursor=Cursors.Hand,BackColor=primary?accent:Color.White,ForeColor=primary?Color.White:ink,UseVisualStyleBackColor=false};
      button.FlatAppearance.BorderColor=primary?accent:Color.FromArgb(220,225,235);button.FlatAppearance.BorderSize=1;return button;
    }
    void BuildUI() {
      Controls.Add(LabelAt("让 Codex，换一幅风景。",28,24,720,44,23f,ink));
      Controls.Add(LabelAt("自定义图片壁纸 · 调整后自动保存并同步到 Codex",30,74,800,24,10f,muted));
      enabled.Text="开启壁纸";enabled.Location=new Point(835,39);enabled.Size=new Size(132,34);enabled.Appearance=Appearance.Button;enabled.TextAlign=ContentAlignment.MiddleCenter;
      enabled.FlatStyle=FlatStyle.Flat;enabled.FlatAppearance.BorderColor=Color.FromArgb(218,224,236);enabled.BackColor=Color.White;enabled.Cursor=Cursors.Hand;
      enabled.CheckedChanged+=delegate {if(!loading) Change("enabled",enabled.Checked);};Controls.Add(enabled);
      var left=new Panel {Location=new Point(28,118),Size=new Size(528,450),BackColor=Color.White};Controls.Add(left);
      left.Controls.Add(LabelAt("效果预览",18,16,350,27,11f,ink));
      left.Controls.Add(LabelAt("示意预览，实际效果以 Codex 窗口为准",18,47,490,22,8.5f,muted));
      preview.Location=new Point(16,82);preview.Size=new Size(496,350);left.Controls.Add(preview);
      var right=new Panel {Location=new Point(578,118),Size=new Size(394,450),BackColor=Color.White};Controls.Add(right);
      right.Controls.Add(LabelAt("壁纸图片",18,16,260,24,11f,ink));
      imagePath.Location=new Point(18,54);imagePath.Size=new Size(272,26);imagePath.ReadOnly=true;imagePath.BorderStyle=BorderStyle.FixedSingle;imagePath.BackColor=Color.FromArgb(248,249,252);right.Controls.Add(imagePath);
      var choose=ButtonAt("选图",298,52,78,30,false);choose.Click+=delegate {ChooseImage();};right.Controls.Add(choose);
      right.Controls.Add(LabelAt("PNG / JPG / WebP · 最大 20 MB",18,89,358,20,8f,muted));
      BrightnessSlider=AddSlider(right,"明暗",126,10,200,100,brightnessValue);
      BlurSlider=AddSlider(right,"模糊",207,0,30,0,blurValue);
      TransparencySlider=AddSlider(right,"背景透明度",288,10,100,64,transparencyValue);
      right.Controls.Add(LabelAt("透明度越高，壁纸越清楚",18,353,358,20,8f,muted));
      right.Controls.Add(LabelAt("应用范围",18,394,94,24,9f,ink));
      scope.DropDownStyle=ComboBoxStyle.DropDownList;scope.Items.AddRange(new object[]{"整个 Codex 窗口","仅聊天区域"});scope.Location=new Point(145,391);scope.Size=new Size(231,26);right.Controls.Add(scope);
      scope.SelectedIndexChanged+=delegate {if(!loading) Change("scope",scope.SelectedIndex==0?"window":"chat");};
      BrightnessSlider.ValueChanged+=delegate {brightnessValue.Text=BrightnessSlider.Value+"%";if(!loading) Change("brightness",BrightnessSlider.Value/100.0);};
      BlurSlider.ValueChanged+=delegate {blurValue.Text=BlurSlider.Value+" px";if(!loading) Change("blur",BlurSlider.Value);};
      TransparencySlider.ValueChanged+=delegate {transparencyValue.Text=TransparencySlider.Value+"%";if(!loading) Change("transparency",TransparencySlider.Value);};
      startButton.Text="启动 / 连接 Codex";startButton.Location=new Point(28,586);startButton.Size=new Size(194,40);startButton.FlatStyle=FlatStyle.Flat;startButton.FlatAppearance.BorderSize=0;startButton.BackColor=accent;startButton.ForeColor=Color.White;startButton.Cursor=Cursors.Hand;
      startButton.Click+=async delegate {await StartAsync();};Controls.Add(startButton);
      var restore=ButtonAt("恢复默认外观",236,586,152,40,false);restore.Click+=async delegate {await RestoreAsync();};Controls.Add(restore);
      statusLabel.Location=new Point(412,586);statusLabel.Size=new Size(558,24);statusLabel.ForeColor=muted;Controls.Add(statusLabel);
      hintLabel.Location=new Point(412,611);hintLabel.Size=new Size(558,40);hintLabel.Font=new Font("Microsoft YaHei UI",8f);hintLabel.ForeColor=muted;Controls.Add(hintLabel);
    }
    TrackBar AddSlider(Panel parent,string text,int y,int min,int max,int value,Label label) {
      parent.Controls.Add(LabelAt(text,18,y,255,26,10f,ink));
      label.Location=new Point(295,y);label.Size=new Size(81,24);label.TextAlign=ContentAlignment.TopRight;label.ForeColor=accent;parent.Controls.Add(label);
      var slider=new TrackBar {Minimum=min,Maximum=max,Value=value,TickStyle=TickStyle.None,SmallChange=1,LargeChange=Math.Max(1,(max-min)/10),Location=new Point(12,y+29),Size=new Size(369,36),AutoSize=false};parent.Controls.Add(slider);return slider;
    }
    void ChooseImage() {
      using(var dialog=new OpenFileDialog {Title="选择 Codex 壁纸",Filter="壁纸图片|*.png;*.jpg;*.jpeg;*.webp|所有文件|*.*",CheckFileExists=true,Multiselect=false}) {
        if(!String.IsNullOrEmpty(settings.imagePath)&&File.Exists(settings.imagePath)) dialog.InitialDirectory=Path.GetDirectoryName(settings.imagePath);
        if(dialog.ShowDialog(this)==DialogResult.OK) {
          if(new FileInfo(dialog.FileName).Length>20*1024*1024) {MessageBox.Show(this,"图片不能超过 20 MB。","选择壁纸",MessageBoxButtons.OK,MessageBoxIcon.Information);return;}
          settings.imagePath=dialog.FileName;settings.enabled=true;loading=true;imagePath.Text=dialog.FileName;enabled.Checked=true;loading=false;
          pending["imagePath"]=dialog.FileName;pending["enabled"]=true;QueueApply();
        }
      }
    }
    void Change(string key,object value) {
      pending[key]=value;LastError=null;
      if(key=="enabled") settings.enabled=(bool)value;
      if(key=="brightness") settings.brightness=Convert.ToDouble(value);
      if(key=="blur") settings.blur=Convert.ToDouble(value);
      if(key=="transparency") settings.tint=1-Convert.ToDouble(value)/100;
      if(key=="scope") settings.scope=(string)value;
      QueueApply();
    }
    void QueueApply() {preview.UpdateImage(settings);applyTimer.Stop();applyTimer.Start();statusLabel.Text="正在保存…";hintLabel.Text="";}
    public Task ApplyPendingAsync() {
      applyTimer.Stop();if(busy) return saveTask;
      if(pending.Count==0) return Task.FromResult(0);
      saveTask=SavePendingAsync();return saveTask;
    }
    async Task SavePendingAsync() {
      busy=true;
      try {
        while(pending.Count>0) {
          var change=new Dictionary<string,object>(pending);pending.Clear();
          await controller.ApplyAsync(change);LastError=null;
        }
      }
      catch(Exception error) {LastError=error.Message;closeRequested=false;statusLabel.ForeColor=Color.FromArgb(182,55,65);statusLabel.Text="设置未保存";hintLabel.Text=LastError;}
      finally {busy=false;}
      if(pending.Count>0) applyTimer.Start();else if(LastError==null) {ReloadSettings();if(closeRequested&&!IsDisposed) BeginInvoke(new Action(Close));}
    }
    public async Task RestoreAsync() {
      pending["enabled"]=false;settings.enabled=false;loading=true;enabled.Checked=false;loading=false;preview.UpdateImage(settings);await ApplyPendingAsync();
    }
    async Task StartAsync() {
      startButton.Enabled=false;
      try {
        if(!settings.enabled) {pending["enabled"]=true;settings.enabled=true;}
        await ApplyPendingAsync();if(LastError!=null) return;
        controller.StartLoader();launching=true;statusLabel.ForeColor=muted;statusLabel.Text="已发出启动请求";
        hintLabel.Text="若 Codex 正在普通模式运行，请从托盘完全退出，加载器会自动重新打开。";
        await Task.Delay(1800);launching=false;RefreshStatus();
      } catch(Exception error) {LastError=error.Message;statusLabel.Text="启动失败";hintLabel.Text=error.Message;}
      finally {if(!IsDisposed) startButton.Enabled=true;launching=false;}
    }
    public void ReloadSettings() {
      try {
        var state=controller.Read();settings=state.settings;loading=true;
        imagePath.Text=settings.imagePath??"";enabled.Checked=settings.enabled;enabled.Text=settings.enabled?"壁纸已开启":"开启壁纸";
        BrightnessSlider.Value=Math.Max(10,Math.Min(200,(int)Math.Round(settings.brightness*100)));
        BlurSlider.Value=Math.Max(0,Math.Min(30,(int)Math.Round(settings.blur)));
        TransparencySlider.Value=Math.Max(10,Math.Min(100,(int)Math.Round((1-settings.tint)*100)));
        brightnessValue.Text=BrightnessSlider.Value+"%";blurValue.Text=BlurSlider.Value+" px";transparencyValue.Text=TransparencySlider.Value+"%";
        scope.SelectedIndex=settings.scope=="chat"?1:0;preview.UpdateImage(settings);loading=false;
        if(LastError==null) SetStatus(state);
      } catch(Exception error) {loading=false;LastError=error.Message;statusLabel.Text="无法读取设置";hintLabel.Text=error.Message;}
    }
    void RefreshStatus() {if(LastError!=null) return;try {SetStatus(controller.Read());} catch {}}
    void SetStatus(WallpaperState state) {
      statusLabel.ForeColor=muted;hintLabel.Text="关闭设置窗口不会中断已连接的壁纸加载器。";
      if(!state.live.running) {
        statusLabel.Text=state.settings.enabled?"● 设置已保存 · 加载器未连接":"● 关闭壁纸的设置已保存 · 加载器未连接";
        hintLabel.Text="从壁纸入口启动 Codex 后，将应用保存的设置。";
        if(state.live.state=="failed") hintLabel.Text="上次加载失败，可点击「启动 / 连接 Codex」重试。";
        return;
      }
      if(state.live.state=="waiting-for-codex-exit") {statusLabel.Text="● 等待 Codex 完全退出";hintLabel.Text="请从托盘退出 Codex，加载器会自动重新打开。";return;}
      if(state.live.state=="active"&&state.live.applied) {statusLabel.Text="● 已连接 Codex · 壁纸已生效";statusLabel.ForeColor=Color.FromArgb(31,135,103);return;}
      if(state.live.state=="disabled"&&state.live.applied) {statusLabel.Text="● 已连接 Codex · 默认外观";return;}
      if(state.live.mainReady) {statusLabel.Text="● 设置已保存 · 等待同步";return;}
      statusLabel.Text="● 正在连接 Codex…";
    }
  }
  internal static class Program {
    [DllImport("user32.dll")] static extern IntPtr FindWindow(string className,string title);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr handle,int command);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
    [STAThread] static void Main() {
      Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
      string root=AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
      string key;using(var hash=SHA256.Create()) key=BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(root.ToUpperInvariant()))).Replace("-","");
      bool created;using(var mutex=new Mutex(true,"Local\\CodexWallpaperSettings-"+key,out created)) {
        if(!created) {var window=FindWindow(null,"Codex 壁纸设置");if(window!=IntPtr.Zero) {ShowWindow(window,9);SetForegroundWindow(window);}return;}
        try {Application.Run(new SettingsForm(root));}
        catch(Exception error) {MessageBox.Show(error.Message,"Codex 壁纸设置",MessageBoxButtons.OK,MessageBoxIcon.Error);}
      }
    }
  }
}
