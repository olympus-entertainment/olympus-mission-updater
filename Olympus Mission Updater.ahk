#Requires AutoHotkey v2.0
#Include lib\util.ahk
#SingleInstance Force


if not A_IsCompiled
  TraySetIcon("img/logo.ico")

;initial call to API for mission file list
data := get_mission_files(2)

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
dl_btn.OnEvent("Click", download_click.Bind(data))

m_gui["LifeSelectAll"].OnEvent("Click", select_all.Bind(lv))
m_gui["ConquestSelectAll"].OnEvent("Click", select_all.Bind(lv1))
m_gui.Show

;initial load of listviews
load_lists(data)