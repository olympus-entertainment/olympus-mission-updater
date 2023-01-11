#Requires AutoHotkey v2.0
#Include lib\jxon.ahk
#Include lib\md5.ahk

#SingleInstance Force

MP_MISSIONS := EnvGet("LOCALAPPDATA") "\Arma 3\MPMissionsCache\"

;prob shouldn't be a global var but yolo
global checked_files := []

if not A_IsCompiled
  TraySetIcon("img/logo.png")

m_gui := Gui(, "Olympus Mission File Updater")

;add lv on life tab
m_gui.Add("Text",, "ALTIS LIFE")
m_gui.AddCheckBox("vLifeSelectAll", "Select All")
lv := m_gui.Add("ListView", "r20 w400 h125 Redraw Checked", [])
lv.InsertCol(1, "240" ,"Name")
lv.InsertCol(3, "75" , "Size")
lv.InsertCol(4, "75" ,"Up to date")

;add lv on cq tab
m_gui.Add("Text",, "CONQUEST")
m_gui.AddCheckBox("vConquestSelectAll", "Select All")
lv1 := m_gui.Add("ListView", "r20 w400 h250 Redraw Checked", [])
lv1.InsertCol(1, "240" ,"Name")
lv1.InsertCol(3, "75" , "Size")
lv1.InsertCol(4, "75" ,"Up to date")

lv.OnEvent("ItemCheck", do_checked)
lv1.OnEvent("ItemCheck", do_checked)

dl_btn := m_gui.AddButton("xm W400 disabled","Download")
dl_btn.OnEvent("Click", download_click)

m_gui["LifeSelectAll"].OnEvent("Click", select_all.Bind(lv))
m_gui["ConquestSelectAll"].OnEvent("Click", select_all.Bind(lv1))
m_gui.Show

url := "https://stats.olympus-entertainment.com/api/v3.0/public/mission/latest/"

http := ComObject("WinHttp.WinHttpRequest.5.1")
http.Open("GET", url, false)
http.Send()
http.WaitForResponse()

contents := http.ResponseText
data := Jxon_load(&contents)

;initial load of listviews
load_lists()

;event handler for when checkboxes are checked
do_checked(ctrlobj, item, checked) {
    ;if row is checked add to list to download
    if(checked) {
        name := ctrlobj.GetText(item)
        checked_files.Push(name)
    } else if (!checked && checked_files.Length > 0) {
        index := HasVal(checked_files, ctrlobj.GetText(item))
        checked_files.RemoveAt(index)
    }
    ;dl button toggle
    if(checked_files.Length > 0)
        dl_btn.Enabled := true
    else
        dl_btn.Enabled := false
}

download_click(*)
{
    p_gui := Gui("-Caption +Owner" m_gui.Hwnd)
    p_gui.AddText("w200 vDownloadText", "Downloading")
    p_gui.AddProgress("w200 h20 cBlue vMyProgress")
    p_gui.Show()    
    m_gui.GetPos(&m_gui_x, &m_gui_y, &m_gui_width, &m_gui_height)
    p_gui.GetPos(,, &p_gui_width, &p_gui_height)
    p_gui.Move(m_gui_x + ((m_gui_width - p_gui_width) // 2), m_gui_y + ((m_gui_height - p_gui_height) // 2))


    ;messy but works 
    for(mission in data) {
        for(selected in checked_files) {
            if (mission["name"] == selected) {
                path := MP_MISSIONS mission["name"]
                ;if the file exists and the hash matches
                if(!FileExist(path) || HashFile(path) != mission["hash"] ) {
                    req := ComObject("WinHttp.WinHttpRequest.5.1")
                    req.Open("GET", mission["url"], false)
                    req.Send()
                    req.WaitForResponse()
                    if !(req.status = 200) {
                        MsgBox("Failed while downloading PBO: " mission["name"] ", please try again later")
                        p_gui["MyProgress"].Value += 1 / checked_files.Length * 100
                    } else {
                        Arr := req.responseBody
                        p_data := NumGet(ComObjValue(Arr) + 8 + A_PtrSize, "UPtr")
                        len := Arr.MaxIndex() + 1
                        FileOpen(path, "w").RawWrite(p_data + 0, len)
                        p_gui["MyProgress"].Value += 1 / checked_files.Length * 100
                    }
                }
            }
        }
    }
    p_gui["MyProgress"].Value += 100
    p_gui["DownloadText"].Text := "Download Complete!"
    sleep(2000)
    ;reset form
    lv.Delete()
    lv1.Delete()
    load_lists()
    p_gui.Destroy()
    ;unselect all
    ControlSetChecked(0,m_gui["LifeSelectAll"])
    ControlSetChecked(0,m_gui["ConquestSelectAll"])
    select_all(lv)
    select_all(lv1)
    ;clean out array
    if(checked_files.Length > 0)
        checked_files.RemoveAt(1, checked_files.Length)
}

;checks all boxes and add them to list
select_all(arr, *){
    is_checked := InStr(arr.GetText(1), "life") ? ControlGetChecked(m_gui["LifeSelectAll"]) : ControlGetChecked(m_gui["ConquestSelectAll"])
    Loop(arr.GetCount()) {
        arr.Modify(A_Index, is_checked ? "Check" : "-Check")
        if (is_checked) {
            checked_files.Push(arr.GetText(A_Index))
            dl_btn.Enabled := true
        }
        else {
            index := HasVal(checked_files, arr.GetText(A_Index))
            if(index != -1)
                checked_files.RemoveAt(index) 
            dl_btn.Enabled := false
        }
    }
    return
}

;load listviews from json data from api
;compare local file hash if it exists with hash stored on server
load_lists() {
    for (index,mission in data) {
        file_hash := ""
        if(FileExist(MP_MISSIONS mission["name"]))
            file_hash := HashFile(MP_MISSIONS mission["name"])
        if (mission["type"] == "LIFE") {
            lv.Add(,mission["name"], Format("{:d}", (mission["size"] / 1048576)) " MB", file_hash == mission["hash"] ? "✓" : "✘")
            ControlSetChecked(1,m_gui["LifeSelectAll"])
            checked_files.Push(mission["name"])
            lv.Modify(index, "Check")
            dl_btn.Enabled := true
        }
        if(mission["type"] == "CONQUEST") {
            lv1.Add(,mission["name"], Format("{:d}", (mission["size"] / 1048576)) " MB", file_hash == mission["hash"] ? "✓" : "✘")
        }
    }
}

;essentially just indexOf but slower cause ahk is meh
HasVal(haystack, needle) {
	if !(IsObject(haystack)) || (haystack.Length == 0)
		return -1
	for index, value in haystack
		if (value = needle)
			return index
	return -1
}