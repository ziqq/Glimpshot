#!/usr/bin/env python3
# https://github.com/ziqq/Glimpshot
# Copyright (C) 2026 Anton Ustinoff
# https://github.com/ziqq/Glimpshot/blob/main/LICENSE

"""Single source of truth for UI strings. Run to regenerate Resources/<lang>.lproj/Localizable.strings.

Columns: en, ru, uk, de, fr, es, it, pt-BR, ja, ko, zh-Hans
"""
import os

LANGS = ["en", "ru", "uk", "de", "fr", "es", "it", "pt-BR", "ja", "ko", "zh-Hans"]

S = {
"tool.select": ["Move", "Перемещение", "Переміщення", "Verschieben", "Déplacer", "Mover", "Sposta", "Mover", "移動", "이동", "移动"],
"tool.pen": ["Pen", "Карандаш", "Олівець", "Stift", "Crayon", "Lápiz", "Matita", "Caneta", "ペン", "펜", "画笔"],
"tool.line": ["Line", "Линия", "Лінія", "Linie", "Ligne", "Línea", "Linea", "Linha", "線", "선", "直线"],
"tool.arrow": ["Arrow", "Стрелка", "Стрілка", "Pfeil", "Flèche", "Flecha", "Freccia", "Seta", "矢印", "화살표", "箭头"],
"tool.rect": ["Rectangle", "Прямоугольник", "Прямокутник", "Rechteck", "Rectangle", "Rectángulo", "Rettangolo", "Retângulo", "四角形", "사각형", "矩形"],
"tool.ellipse": ["Ellipse", "Эллипс", "Еліпс", "Ellipse", "Ellipse", "Elipse", "Ellisse", "Elipse", "楕円", "타원", "椭圆"],
"tool.marker": ["Highlighter", "Маркер", "Маркер", "Textmarker", "Surligneur", "Resaltador", "Evidenziatore", "Marca-texto", "蛍光ペン", "형광펜", "荧光笔"],
"tool.text": ["Text", "Текст", "Текст", "Text", "Texte", "Texto", "Testo", "Texto", "テキスト", "텍스트", "文字"],
"tool.pixelate": ["Pixelate", "Пикселизация", "Пікселізація", "Verpixeln", "Pixelliser", "Pixelar", "Pixella", "Pixelizar", "モザイク", "모자이크", "马赛克"],
"tool.counter": ["Counter", "Нумерация", "Нумерація", "Zähler", "Numéroteur", "Contador", "Contatore", "Contador", "番号", "번호", "编号"],

"style.color": ["Color", "Цвет", "Колір", "Farbe", "Couleur", "Color", "Colore", "Cor", "色", "색상", "颜色"],
"style.thin": ["Thin", "Тонкая", "Тонка", "Dünn", "Fin", "Fino", "Sottile", "Fino", "細い", "얇게", "细"],
"style.medium": ["Medium", "Средняя", "Середня", "Mittel", "Moyen", "Medio", "Medio", "Médio", "標準", "보통", "中"],
"style.thick": ["Thick", "Толстая", "Товста", "Dick", "Épais", "Grueso", "Spesso", "Grosso", "太い", "굵게", "粗"],

"action.undo": ["Undo", "Отменить", "Скасувати", "Widerrufen", "Annuler", "Deshacer", "Annulla", "Desfazer", "取り消す", "실행 취소", "撤销"],
"action.redo": ["Redo", "Повторить", "Повторити", "Wiederholen", "Rétablir", "Rehacer", "Ripeti", "Refazer", "やり直す", "다시 실행", "重做"],
"action.pin": ["Pin on Top", "Закрепить поверх окон", "Закріпити поверх вікон", "Oben anheften", "Épingler au premier plan", "Fijar encima", "Fissa in primo piano", "Fixar no topo", "最前面に固定", "맨 위에 고정", "置顶"],
"action.saveAs": ["Save As…", "Сохранить как…", "Зберегти як…", "Sichern unter …", "Enregistrer sous…", "Guardar como…", "Salva con nome…", "Salvar como…", "名前を付けて保存…", "다른 이름으로 저장…", "另存为…"],
"action.save": ["Save to Folder", "Сохранить в папку", "Зберегти в теку", "Im Ordner sichern", "Enregistrer dans le dossier", "Guardar en carpeta", "Salva nella cartella", "Salvar na pasta", "フォルダに保存", "폴더에 저장", "保存到文件夹"],
"action.copy": ["Copy", "Копировать", "Копіювати", "Kopieren", "Copier", "Copiar", "Copia", "Copiar", "コピー", "복사", "拷贝"],
"action.close": ["Close", "Закрыть", "Закрити", "Schließen", "Fermer", "Cerrar", "Chiudi", "Fechar", "閉じる", "닫기", "关闭"],

"menu.captureArea": ["Capture Area", "Снимок области", "Знімок області", "Bereich aufnehmen", "Capturer une zone", "Capturar área", "Cattura area", "Capturar área", "範囲を撮影", "영역 캡처", "截取区域"],
"menu.captureScreen": ["Capture Screen", "Снимок всего экрана", "Знімок усього екрана", "Bildschirm aufnehmen", "Capturer l’écran", "Capturar pantalla", "Cattura schermo", "Capturar tela", "画面全体を撮影", "전체 화면 캡처", "截取整个屏幕"],
"menu.history": ["History…", "История…", "Історія…", "Verlauf …", "Historique…", "Historial…", "Cronologia…", "Histórico…", "履歴…", "기록…", "历史记录…"],
"menu.openFolder": ["Open Screenshots Folder", "Открыть папку со снимками", "Відкрити теку зі знімками", "Bildschirmfoto-Ordner öffnen", "Ouvrir le dossier des captures", "Abrir carpeta de capturas", "Apri cartella catture", "Abrir pasta de capturas", "スクリーンショットのフォルダを開く", "스크린샷 폴더 열기", "打开截图文件夹"],
"menu.settings": ["Settings…", "Настройки…", "Налаштування…", "Einstellungen …", "Réglages…", "Ajustes…", "Impostazioni…", "Ajustes…", "設定…", "설정…", "设置…"],
"menu.about": ["About %@", "О программе %@", "Про %@", "Über %@", "À propos de %@", "Acerca de %@", "Informazioni su %@", "Sobre o %@", "%@について", "%@ 정보", "关于 %@"],
"menu.quit": ["Quit %@", "Выйти из %@", "Вийти з %@", "%@ beenden", "Quitter %@", "Salir de %@", "Esci da %@", "Encerrar %@", "%@を終了", "%@ 종료", "退出 %@"],

"perm.title": ["Screen Recording access needed", "Нужен доступ к записи экрана", "Потрібен доступ до запису екрана", "Zugriff auf Bildschirmaufnahme erforderlich", "Accès à l’enregistrement de l’écran requis", "Se necesita acceso a la grabación de pantalla", "Serve l’accesso alla registrazione dello schermo", "É necessário acesso à gravação de tela", "画面収録へのアクセスが必要です", "화면 기록 권한이 필요합니다", "需要屏幕录制权限"],
"perm.body": [
  "Open System Settings → Privacy & Security → Screen & System Audio Recording, turn on %1$@ and relaunch the app.\n\nError: %2$@",
  "Откройте «Системные настройки» → «Конфиденциальность и безопасность» → «Запись экрана и системного звука», включите %1$@ и перезапустите приложение.\n\nОшибка: %2$@",
  "Відкрийте «Системні параметри» → «Приватність і безпека» → «Запис екрана і системного звуку», увімкніть %1$@ і перезапустіть програму.\n\nПомилка: %2$@",
  "Öffne Systemeinstellungen → Datenschutz & Sicherheit → Bildschirm- & Systemaudioaufnahme, aktiviere %1$@ und starte die App neu.\n\nFehler: %2$@",
  "Ouvrez Réglages Système → Confidentialité et sécurité → Enregistrement de l’écran et de l’audio système, activez %1$@ puis relancez l’app.\n\nErreur : %2$@",
  "Abre Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla y audio del sistema, activa %1$@ y vuelve a abrir la app.\n\nError: %2$@",
  "Apri Impostazioni di Sistema → Privacy e sicurezza → Registrazione schermo e audio di sistema, attiva %1$@ e riavvia l’app.\n\nErrore: %2$@",
  "Abra Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema, ative %1$@ e reabra o app.\n\nErro: %2$@",
  "システム設定 → プライバシーとセキュリティ → 画面収録とシステムオーディオ録音 で %1$@ をオンにし、アプリを再起動してください。\n\nエラー: %2$@",
  "시스템 설정 → 개인정보 보호 및 보안 → 화면 및 시스템 오디오 기록에서 %1$@을(를) 켜고 앱을 다시 실행하세요.\n\n오류: %2$@",
  "打开“系统设置”→“隐私与安全性”→“录屏与系统录音”，开启 %1$@ 并重新启动应用。\n\n错误：%2$@",
],
"perm.openSettings": ["Open Settings", "Открыть настройки", "Відкрити параметри", "Einstellungen öffnen", "Ouvrir les réglages", "Abrir ajustes", "Apri impostazioni", "Abrir ajustes", "設定を開く", "설정 열기", "打开设置"],
"perm.relaunch": ["Relaunch %@", "Перезапустить %@", "Перезапустити %@", "%@ neu starten", "Relancer %@", "Reiniciar %@", "Riavvia %@", "Reabrir %@", "%@を再起動", "%@ 다시 시작", "重新启动 %@"],
"perm.later": ["Later", "Позже", "Пізніше", "Später", "Plus tard", "Más tarde", "Più tardi", "Mais tarde", "後で", "나중에", "稍后"],

"window.history": ["Screenshot History", "История снимков", "Історія знімків", "Bildschirmfoto-Verlauf", "Historique des captures", "Historial de capturas", "Cronologia catture", "Histórico de capturas", "スクリーンショット履歴", "스크린샷 기록", "截图历史"],
"window.settings": ["%@ Settings", "Настройки %@", "Налаштування %@", "%@ – Einstellungen", "Réglages de %@", "Ajustes de %@", "Impostazioni di %@", "Ajustes do %@", "%@ 設定", "%@ 설정", "%@ 设置"],

"about.tagline": ["Fast screenshots with annotations. Everything stays on your Mac.", "Быстрые скриншоты с аннотациями. Всё хранится локально.", "Швидкі знімки з анотаціями. Усе зберігається локально.", "Schnelle Bildschirmfotos mit Anmerkungen. Alles bleibt auf deinem Mac.", "Captures rapides avec annotations. Tout reste sur votre Mac.", "Capturas rápidas con anotaciones. Todo se queda en tu Mac.", "Catture rapide con annotazioni. Tutto resta sul tuo Mac.", "Capturas rápidas com anotações. Tudo fica no seu Mac.", "注釈付きのすばやいスクリーンショット。すべてMac内に保存されます。", "주석이 있는 빠른 스크린샷. 모든 데이터는 Mac에만 저장됩니다.", "带标注的快速截图，所有内容都保存在你的 Mac 上。"],
"about.version": ["Version %@", "Версия %@", "Версія %@", "Version %@", "Version %@", "Versión %@", "Versione %@", "Versão %@", "バージョン %@", "버전 %@", "版本 %@"],

"overlay.hint": ["Select an area or click a window  ·  Esc to cancel", "Выделите область или кликните по окну  ·  Esc — отмена", "Виділіть область або клацніть по вікну  ·  Esc — скасувати", "Bereich auswählen oder auf ein Fenster klicken  ·  Esc zum Abbrechen", "Sélectionnez une zone ou cliquez sur une fenêtre  ·  Échap pour annuler", "Selecciona un área o haz clic en una ventana  ·  Esc para cancelar", "Seleziona un’area o fai clic su una finestra  ·  Esc per annullare", "Selecione uma área ou clique numa janela  ·  Esc para cancelar", "範囲を選択するかウインドウをクリック  ·  Esc でキャンセル", "영역을 선택하거나 창을 클릭하세요  ·  Esc로 취소", "选择区域或点按窗口  ·  按 Esc 取消"],

"toast.copied": ["Copied to clipboard", "Скопировано в буфер обмена", "Скопійовано в буфер обміну", "In die Zwischenablage kopiert", "Copié dans le presse-papiers", "Copiado al portapapeles", "Copiato negli appunti", "Copiado para a área de transferência", "クリップボードにコピーしました", "클립보드에 복사됨", "已拷贝到剪贴板"],
"toast.saved": ["Saved", "Сохранено", "Збережено", "Gesichert", "Enregistré", "Guardado", "Salvato", "Salvo", "保存しました", "저장됨", "已保存"],
"toast.savedCopied": ["Saved and copied", "Сохранено и скопировано", "Збережено й скопійовано", "Gesichert und kopiert", "Enregistré et copié", "Guardado y copiado", "Salvato e copiato", "Salvo e copiado", "保存してコピーしました", "저장 및 복사됨", "已保存并拷贝"],
"toast.reveal": ["Click to show in Finder", "Нажмите, чтобы показать в Finder", "Натисніть, щоб показати у Finder", "Klicken, um im Finder anzuzeigen", "Cliquez pour afficher dans le Finder", "Haz clic para mostrar en Finder", "Fai clic per mostrare nel Finder", "Clique para mostrar no Finder", "クリックしてFinderで表示", "클릭하여 Finder에서 보기", "点按以在访达中显示"],

"history.search": ["Search by name", "Поиск по имени", "Пошук за назвою", "Nach Name suchen", "Rechercher par nom", "Buscar por nombre", "Cerca per nome", "Buscar por nome", "名前で検索", "이름으로 검색", "按名称搜索"],
"history.openFolder": ["Open Folder", "Открыть папку", "Відкрити теку", "Ordner öffnen", "Ouvrir le dossier", "Abrir carpeta", "Apri cartella", "Abrir pasta", "フォルダを開く", "폴더 열기", "打开文件夹"],
"history.refresh": ["Refresh", "Обновить", "Оновити", "Aktualisieren", "Actualiser", "Actualizar", "Aggiorna", "Atualizar", "更新", "새로 고침", "刷新"],
"history.empty": ["Nothing here yet", "Пока пусто", "Поки порожньо", "Noch nichts da", "Rien pour l’instant", "Aún no hay nada", "Ancora niente", "Nada por aqui ainda", "まだありません", "아직 없음", "暂无内容"],
"history.noResults": ["No results", "Ничего не найдено", "Нічого не знайдено", "Keine Treffer", "Aucun résultat", "Sin resultados", "Nessun risultato", "Nenhum resultado", "見つかりません", "결과 없음", "无结果"],
"history.emptyDesc": ["Screenshots saved to %@ will appear here.", "Сохранённые снимки из %@ появятся здесь.", "Збережені знімки з %@ з’являться тут.", "In %@ gesicherte Bildschirmfotos erscheinen hier.", "Les captures enregistrées dans %@ apparaîtront ici.", "Las capturas guardadas en %@ aparecerán aquí.", "Le catture salvate in %@ appariranno qui.", "As capturas salvas em %@ aparecerão aqui.", "%@ に保存したスクリーンショットがここに表示されます。", "%@에 저장된 스크린샷이 여기에 표시됩니다.", "保存到 %@ 的截图将显示在这里。"],
"history.tryAnother": ["Try a different search.", "Попробуйте другой запрос.", "Спробуйте інший запит.", "Versuche eine andere Suche.", "Essayez une autre recherche.", "Prueba otra búsqueda.", "Prova un’altra ricerca.", "Tente outra busca.", "別の語句で検索してください。", "다른 검색어를 입력해 보세요.", "请尝试其他搜索。"],
"history.count": ["Screenshots: %ld", "Снимков: %ld", "Знімків: %ld", "Bildschirmfotos: %ld", "Captures : %ld", "Capturas: %ld", "Catture: %ld", "Capturas: %ld", "スクリーンショット: %ld", "스크린샷: %ld", "截图：%ld"],
"history.open": ["Open", "Открыть", "Відкрити", "Öffnen", "Ouvrir", "Abrir", "Apri", "Abrir", "開く", "열기", "打开"],
"history.reveal": ["Show in Finder", "Показать в Finder", "Показати у Finder", "Im Finder zeigen", "Afficher dans le Finder", "Mostrar en Finder", "Mostra nel Finder", "Mostrar no Finder", "Finderで表示", "Finder에서 보기", "在访达中显示"],
"history.trash": ["Move to Trash", "Переместить в корзину", "Перемістити в смітник", "In den Papierkorb legen", "Placer dans la corbeille", "Trasladar a la papelera", "Sposta nel cestino", "Mover para o Lixo", "ゴミ箱に入れる", "휴지통으로 이동", "移到废纸篓"],

"pin.actualSize": ["Actual Size", "Исходный размер", "Початковий розмір", "Originalgröße", "Taille réelle", "Tamaño real", "Dimensioni reali", "Tamanho real", "実際のサイズ", "실제 크기", "实际大小"],

"settings.hotkeys": ["Keyboard Shortcuts", "Горячие клавиши", "Гарячі клавіші", "Tastenkürzel", "Raccourcis clavier", "Atajos de teclado", "Scorciatoie da tastiera", "Atalhos de teclado", "キーボードショートカット", "키보드 단축키", "键盘快捷键"],
"settings.saving": ["Saving", "Сохранение", "Збереження", "Sichern", "Enregistrement", "Guardado", "Salvataggio", "Salvamento", "保存", "저장", "保存"],
"settings.folder": ["Folder", "Папка", "Тека", "Ordner", "Dossier", "Carpeta", "Cartella", "Pasta", "フォルダ", "폴더", "文件夹"],
"settings.choose": ["Choose…", "Выбрать…", "Вибрати…", "Auswählen …", "Choisir…", "Elegir…", "Scegli…", "Escolher…", "選択…", "선택…", "选择…"],
"settings.format": ["Format", "Формат", "Формат", "Format", "Format", "Formato", "Formato", "Formato", "フォーマット", "형식", "格式"],
"settings.copyOnSave": ["Copy to clipboard when saving", "Копировать в буфер при сохранении", "Копіювати в буфер під час збереження", "Beim Sichern in die Zwischenablage kopieren", "Copier dans le presse-papiers à l’enregistrement", "Copiar al portapapeles al guardar", "Copia negli appunti al salvataggio", "Copiar para a área de transferência ao salvar", "保存時にクリップボードにコピー", "저장 시 클립보드에 복사", "保存时拷贝到剪贴板"],
"settings.appearance": ["Appearance", "Оформление", "Вигляд", "Erscheinungsbild", "Apparence", "Apariencia", "Aspetto", "Aparência", "外観", "화면 모드", "外观"],
"settings.accent": ["Accent color", "Акцентный цвет", "Акцентний колір", "Akzentfarbe", "Couleur d’accentuation", "Color de acento", "Colore di accento", "Cor de destaque", "アクセントカラー", "강조 색상", "强调色"],
"settings.menuBarIcon": ["Menu bar icon", "Иконка в меню‑баре", "Іконка в рядку меню", "Symbol in der Menüleiste", "Icône de la barre des menus", "Icono de la barra de menús", "Icona nella barra dei menu", "Ícone da barra de menus", "メニューバーのアイコン", "메뉴 막대 아이콘", "菜单栏图标"],
"settings.language": ["Language", "Язык", "Мова", "Sprache", "Langue", "Idioma", "Lingua", "Idioma", "言語", "언어", "语言"],
"settings.languageSystem": ["System", "Как в системе", "Як у системі", "System", "Système", "Sistema", "Sistema", "Sistema", "システム", "시스템", "跟随系统"],
"settings.languageRestart": ["Relaunch to apply the language.", "Перезапустите, чтобы сменить язык.", "Перезапустіть, щоб змінити мову.", "Neu starten, um die Sprache zu übernehmen.", "Relancez pour appliquer la langue.", "Reinicia para aplicar el idioma.", "Riavvia per applicare la lingua.", "Reabra para aplicar o idioma.", "言語を適用するには再起動してください。", "언어를 적용하려면 다시 시작하세요.", "重新启动以应用语言。"],
"settings.relaunchNow": ["Relaunch Now", "Перезапустить", "Перезапустити", "Jetzt neu starten", "Relancer", "Reiniciar ahora", "Riavvia ora", "Reabrir agora", "今すぐ再起動", "지금 다시 시작", "立即重新启动"],
"settings.behavior": ["Behavior", "Поведение", "Поведінка", "Verhalten", "Comportement", "Comportamiento", "Comportamento", "Comportamento", "動作", "동작", "行为"],
"settings.sound": ["Shutter sound", "Звук затвора", "Звук затвора", "Auslöserton", "Son de l’obturateur", "Sonido del obturador", "Suono dell’otturatore", "Som do obturador", "シャッター音", "셔터 소리", "快门声"],
"settings.loupe": ["Magnifier while selecting", "Лупа при выделении", "Лупа під час виділення", "Lupe bei der Auswahl", "Loupe pendant la sélection", "Lupa al seleccionar", "Lente durante la selezione", "Lupa ao selecionar", "選択中に拡大鏡を表示", "선택 중 돋보기", "选择时显示放大镜"],
"settings.preview": ["Preview in corner after capture", "Превью в углу после снимка", "Прев’ю в куті після знімка", "Vorschau in der Ecke nach der Aufnahme", "Aperçu dans le coin après la capture", "Vista previa en la esquina tras capturar", "Anteprima nell’angolo dopo la cattura", "Pré-visualização no canto após capturar", "撮影後に隅にプレビュー", "캡처 후 모서리에 미리보기", "截图后在角落预览"],
"settings.launchAtLogin": ["Launch at login", "Запускать при входе в систему", "Запускати під час входу", "Beim Anmelden starten", "Ouvrir à la connexion", "Abrir al iniciar sesión", "Apri al login", "Abrir ao iniciar sessão", "ログイン時に起動", "로그인 시 실행", "登录时启动"],
"settings.updates": ["Updates", "Обновления", "Оновлення", "Updates", "Mises à jour", "Actualizaciones", "Aggiornamenti", "Atualizações", "アップデート", "업데이트", "更新"],
"settings.editorKeys": ["Editor Shortcuts", "Клавиши в редакторе", "Клавіші в редакторі", "Kurzbefehle im Editor", "Raccourcis de l’éditeur", "Atajos del editor", "Scorciatoie dell’editor", "Atalhos do editor", "エディタのショートカット", "편집기 단축키", "编辑器快捷键"],

"hint.copy": ["copy and close", "копировать и закрыть", "копіювати й закрити", "kopieren und schließen", "copier et fermer", "copiar y cerrar", "copia e chiudi", "copiar e fechar", "コピーして閉じる", "복사 후 닫기", "拷贝并关闭"],
"hint.save": ["save to folder / save as…", "сохранить в папку / как…", "зберегти в теку / як…", "im Ordner sichern / sichern unter …", "enregistrer / enregistrer sous…", "guardar en carpeta / como…", "salva nella cartella / con nome…", "salvar na pasta / como…", "フォルダに保存 / 名前を付けて保存", "폴더에 저장 / 다른 이름으로", "保存到文件夹 / 另存为"],
"hint.pin": ["pin on top of windows", "закрепить поверх окон", "закріпити поверх вікон", "über allen Fenstern anheften", "épingler au premier plan", "fijar encima de las ventanas", "fissa sopra le finestre", "fixar sobre as janelas", "ウインドウの最前面に固定", "창 위에 고정", "置顶于所有窗口"],
"hint.undo": ["undo / redo", "отменить / повторить", "скасувати / повторити", "widerrufen / wiederholen", "annuler / rétablir", "deshacer / rehacer", "annulla / ripeti", "desfazer / refazer", "取り消す / やり直す", "실행 취소 / 다시 실행", "撤销 / 重做"],
"hint.tools": ["tools", "инструменты", "інструменти", "Werkzeuge", "outils", "herramientas", "strumenti", "ferramentas", "ツール", "도구", "工具"],
"hint.colors": ["color", "цвет", "колір", "Farbe", "couleur", "color", "colore", "cor", "色", "색상", "颜色"],
"hint.shiftKeys": ["⇧ + drag", "⇧ + рисование", "⇧ + малювання", "⇧ + Ziehen", "⇧ + glisser", "⇧ + arrastrar", "⇧ + trascina", "⇧ + arrastar", "⇧ + ドラッグ", "⇧ + 드래그", "⇧ + 拖移"],
"hint.shift": ["straight lines, square, circle", "ровные линии, квадрат, круг", "рівні лінії, квадрат, коло", "gerade Linien, Quadrat, Kreis", "lignes droites, carré, cercle", "líneas rectas, cuadrado, círculo", "linee dritte, quadrato, cerchio", "linhas retas, quadrado, círculo", "直線・正方形・正円", "직선, 정사각형, 원", "直线、正方形、圆形"],
"hint.arrows": ["move selection (⇧ ×10, ⌥ resize)", "сдвиг рамки (⇧ ×10, ⌥ — размер)", "зсув рамки (⇧ ×10, ⌥ — розмір)", "Auswahl bewegen (⇧ ×10, ⌥ Größe)", "déplacer la sélection (⇧ ×10, ⌥ taille)", "mover selección (⇧ ×10, ⌥ tamaño)", "sposta selezione (⇧ ×10, ⌥ dimensione)", "mover seleção (⇧ ×10, ⌥ tamanho)", "選択範囲を移動（⇧ ×10、⌥ サイズ）", "선택 영역 이동(⇧ ×10, ⌥ 크기)", "移动选区（⇧ ×10，⌥ 调整大小）"],

"recorder.prompt": ["Press shortcut…", "Нажмите сочетание…", "Натисніть сполучення…", "Kurzbefehl drücken …", "Appuyez sur le raccourci…", "Pulsa el atajo…", "Premi la scorciatoia…", "Pressione o atalho…", "ショートカットを押す…", "단축키를 누르세요…", "按下快捷键…"],
"recorder.none": ["Not set", "Не задано", "Не задано", "Nicht festgelegt", "Aucun", "Sin asignar", "Non impostata", "Não definido", "未設定", "설정 안 됨", "未设置"],
"recorder.clear": ["Disable", "Отключить", "Вимкнути", "Deaktivieren", "Désactiver", "Desactivar", "Disattiva", "Desativar", "無効にする", "끄기", "停用"],

"updates.auto": ["Check for updates automatically", "Проверять обновления автоматически", "Перевіряти оновлення автоматично", "Automatisch nach Updates suchen", "Rechercher les mises à jour automatiquement", "Buscar actualizaciones automáticamente", "Controlla aggiornamenti automaticamente", "Verificar atualizações automaticamente", "アップデートを自動的に確認", "자동으로 업데이트 확인", "自动检查更新"],
"updates.checkNow": ["Check Now", "Проверить сейчас", "Перевірити зараз", "Jetzt prüfen", "Vérifier maintenant", "Buscar ahora", "Controlla ora", "Verificar agora", "今すぐ確認", "지금 확인", "立即检查"],
"updates.checking": ["Checking…", "Проверяю…", "Перевіряю…", "Wird geprüft …", "Vérification…", "Buscando…", "Controllo…", "Verificando…", "確認中…", "확인 중…", "正在检查…"],
"updates.upToDate": ["You’re up to date (%@)", "Установлена последняя версия (%@)", "Встановлено останню версію (%@)", "Du bist auf dem neuesten Stand (%@)", "Vous êtes à jour (%@)", "Tienes la última versión (%@)", "Sei aggiornato (%@)", "Você está atualizado (%@)", "最新バージョンです（%@）", "최신 버전입니다(%@)", "已是最新版本（%@）"],
"updates.available": ["Version %@ is available", "Доступна версия %@", "Доступна версія %@", "Version %@ ist verfügbar", "La version %@ est disponible", "La versión %@ está disponible", "È disponibile la versione %@", "A versão %@ está disponível", "バージョン %@ が利用可能です", "버전 %@을(를) 사용할 수 있습니다", "版本 %@ 可用"],
"updates.current": ["You have version %@.", "У вас версия %@.", "У вас версія %@.", "Installiert ist Version %@.", "Vous avez la version %@.", "Tienes la versión %@.", "Hai la versione %@.", "Você tem a versão %@.", "現在のバージョンは %@ です。", "현재 버전은 %@입니다.", "当前版本为 %@。"],
"updates.download": ["Download", "Скачать", "Завантажити", "Laden", "Télécharger", "Descargar", "Scarica", "Baixar", "ダウンロード", "다운로드", "下载"],
"updates.failed": ["Couldn’t check for updates", "Не удалось проверить обновления", "Не вдалося перевірити оновлення", "Suche nach Updates fehlgeschlagen", "Impossible de vérifier les mises à jour", "No se pudo buscar actualizaciones", "Impossibile controllare gli aggiornamenti", "Não foi possível verificar atualizações", "アップデートを確認できませんでした", "업데이트를 확인할 수 없습니다", "无法检查更新"],
}


def escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "Resources")
    for i, lang in enumerate(LANGS):
        d = os.path.join(root, f"{lang}.lproj")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "Localizable.strings"), "w", encoding="utf-8") as f:
            f.write("/* Generated by scripts/strings.py — edit there. */\n\n")
            for key, values in S.items():
                assert len(values) == len(LANGS), key
                f.write(f'"{key}" = "{escape(values[i])}";\n')
    print(f"{len(S)} keys × {len(LANGS)} languages")


if __name__ == "__main__":
    main()
