using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using CodexWallpaper;
class GuiSmoke {
  [STAThread] static int Main(string[] args) {
    string root=Path.Combine(Path.GetTempPath(),"codex-wallpaper-gui-"+Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(Path.Combine(root,"scripts"));
    foreach(string file in new[]{"control.cjs","settings-store.cjs","runtime.cjs"}) File.Copy(Path.Combine(args[0],"scripts",file),Path.Combine(root,"scripts",file));
    string image=Path.Combine(root,"星空 壁纸 & 引号' test.jpg"); File.Copy(args[1],image);
    File.WriteAllText(Path.Combine(root,"settings.json"),new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(new WallpaperSettings {enabled=true,imagePath=image,brightness=1,blur=0,tint=.36,scope="window"}));
    int code=1;
    Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
    using(var form=new SettingsForm(root)) {
      form.Shown+=async delegate {
        try {
          Check(form.BrightnessSlider.Value==100,"initial brightness");
          Check(form.TransparencySlider.Value==64,"initial transparency");
          form.BrightnessSlider.Value=85; form.BlurSlider.Value=4; form.TransparencySlider.Value=72;
          await form.ApplyPendingAsync();
          var client=new WallpaperController(root); var state=client.Read();
          Check(state.settings.imagePath==image,"Unicode image path survives GUI process arguments");
          Check(Math.Abs(state.settings.brightness-.85)<.001&&state.settings.blur==4&&Math.Abs(state.settings.tint-.28)<.001,"sliders save through real Node controller");
          Check(state.settings.enabled&&state.settings.scope=="window","slider changes preserve image and scope");
          form.BrightnessSlider.Value=83;var firstSave=form.ApplyPendingAsync();
          form.BlurSlider.Value=2;var secondSave=form.ApplyPendingAsync();await Task.WhenAll(firstSave,secondSave);
          Check(client.Read().settings.blur==2,"changes made during saving are flushed before the save completes");
          form.BlurSlider.Value=0; await form.ApplyPendingAsync();
          using(var bitmap=new Bitmap(form.Width,form.Height)) { form.DrawToBitmap(bitmap,new Rectangle(0,0,bitmap.Width,bitmap.Height)); bitmap.Save(args[2]); }
          await form.RestoreAsync(); Check(!client.Read().settings.enabled,"restore default disables wallpaper");
          Check(client.Read().settings.imagePath==image,"restore preserves chosen image");
          await client.ApplyAsync(new Dictionary<string,object>{{"enabled",true},{"transparency",80}}); form.ReloadSettings();
          Check(form.TransparencySlider.Value==80,"external skill changes synchronize into GUI");
          Check(form.LastError==null,"GUI has no errors");
          Console.WriteLine("PASS: native form, Unicode path, sliders, restore, and external skill synchronization"); code=0;
        } catch(Exception error) { Console.Error.WriteLine(error); }
        finally { form.Close(); }
      };
      Application.Run(form);
    }
    string resolved=Path.GetFullPath(root); string prefix=Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar+"codex-wallpaper-gui-";
    if(resolved.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)) Directory.Delete(resolved,true);
    return code;
  }
  static void Check(bool ok,string name) { if(!ok) throw new Exception(name); }
}
