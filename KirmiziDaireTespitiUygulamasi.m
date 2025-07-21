function KirmiziDaireTespitiUygulamasi()
    % GUI ELEMANLARI
    fig = figure('Name', 'Kırmızı Daire Takip Sistemi (GUI)', ...
        'NumberTitle', 'off', 'Color', [0.1 0.1 0.1], ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100 100 950 650]);

    % Görüntü paneli
    ax = axes('Parent', fig, 'Units', 'pixels', 'Position', [50 150 640 480]);
    axis off;

    % Konum yazısı
    konumLabel = uicontrol('Style', 'text', ...
        'Parent', fig, ...
        'Position', [700 400 200 120], ...
        'BackgroundColor', [0.2 0.2 0.2], ...
        'ForegroundColor', 'white', ...
        'FontSize', 11, ...
        'HorizontalAlignment', 'left', ...
        'String', 'Kırmızı Daire Konumu:');

    % Alarm kapama
    stopAlarmBtn = uicontrol('Style', 'togglebutton', ...
        'String', 'Alarmı Durdur', ...
        'Position', [700 300 150 40], ...
        'FontSize', 12, ...
        'BackgroundColor', [0.8 0.2 0.2], ...
        'ForegroundColor', 'white');

    % Screenshot
    screenshotBtn = uicontrol('Style', 'pushbutton', ...
        'String', 'Screenshot Al', ...
        'Position', [700 240 150 40], ...
        'FontSize', 12, ...
        'BackgroundColor', [0.2 0.6 0.8], ...
        'ForegroundColor', 'white', ...
        'Callback', @(~,~) screenshot(ax));

    % Kamera Seçimi
    uicontrol('Style', 'text', ...
        'Parent', fig, ...
        'Position', [700 570 150 20], ...
        'BackgroundColor', [0.1 0.1 0.1], ...
        'ForegroundColor', 'white', ...
        'String', 'Kamera Kaynağı:', ...
        'HorizontalAlignment', 'left');

    cameraPopup = uicontrol('Style', 'popupmenu', ...
        'Parent', fig, ...
        'Position', [700 540 200 25], ...
        'String', {'Bilgisayar Kamerası', 'Telefon Kamerası (IP)'}, ...
        'Callback', @(src,~) toggleIP(src));

    ipInput = uicontrol('Style', 'edit', ...
        'Parent', fig, ...
        'Position', [700 500 200 25], ...
        'BackgroundColor', 'white', ...
        'String', 'http://192.168.1.25:8080/video', ...
        'Visible', 'off');

    % Kamera başlatma butonu
    uicontrol('Style', 'pushbutton', ...
        'Parent', fig, ...
        'Position', [700 460 200 30], ...
        'String', 'Kamerayı Başlat', ...
        'FontSize', 12, ...
        'Callback', @(~,~) startCamera());

    % ========== CALLBACK FONKSIYONLARI ========== %

    function toggleIP(src)
        val = src.Value;
        if val == 2
            ipInput.Visible = 'on';
        else
            ipInput.Visible = 'off';
        end
    end

    function startCamera()
        cla(ax); % Önceki görüntüyü temizle
        try
            if cameraPopup.Value == 1
                cam = webcam;
            else
                url = ipInput.String;
                cam = ipcam(url);
            end
        catch
            errordlg('Kamera başlatılamadı. Lütfen bağlantıyı kontrol edin.', 'Kamera Hatası');
            return;
        end

        runTrackingLoop(cam, fig, ax, stopAlarmBtn, konumLabel);
    end

    function screenshot(axHandle)
        % Görüntü panelindeki son görüntüyü kaydet
        frame = getimage(axHandle);
        if isempty(frame)
            warndlg('Kayıt için geçerli bir görüntü yok.', 'Uyarı');
            return;
        end
        [file,path] = uiputfile({'*.png';'*.jpg';'*.bmp'}, 'Ekran Görüntüsünü Kaydet');
        if isequal(file,0)
            return;
        end
        imwrite(frame, fullfile(path, file));
        msgbox('Ekran görüntüsü başarıyla kaydedildi.', 'Başarılı');
    end

end


function runTrackingLoop(cam, fig, ax, stopAlarmBtn, konumLabel)
    alarmCaldi = false;
    while isvalid(fig)
        frame = snapshot(cam);
        imshow(frame, 'Parent', ax);

        % Görüntüyü HSV formatına çevir
        hsvFrame = rgb2hsv(frame);
        h = hsvFrame(:,:,1);
        s = hsvFrame(:,:,2);
        v = hsvFrame(:,:,3);

        % Kırmızı için maske oluştur (iki aralık)
        mask1 = (h < 0.05 | h > 0.95) & s > 0.5 & v > 0.5;
        mask = imfill(mask1, 'holes');
        mask = bwareaopen(mask, 300); % küçük gürültüleri temizle

        % Kontur bul ve çiz
        stats = regionprops(mask, 'Centroid', 'Area', 'BoundingBox');

        if ~isempty(stats)
            [~, idx] = max([stats.Area]);
            center = stats(idx).Centroid;
            rectangle('Position', stats(idx).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2, 'Parent', ax);
            hold(ax, 'on');
            plot(ax, center(1), center(2), 'r+', 'MarkerSize', 10, 'LineWidth', 2);
            hold(ax, 'off');

            % Konumu GUI'de göster
            konumLabel.String = sprintf('Kırmızı Daire Konumu:\nX: %.0f\nY: %.0f', center(1), center(2));

            % Alarm
            if ~alarmCaldi && ~stopAlarmBtn.Value
                sound(sin(1:3000));  % Basit alarm sesi
                alarmCaldi = true;
            end
        else
            konumLabel.String = 'Kırmızı Daire Konumu:\nYok';
            alarmCaldi = false;
        end

        drawnow;
    end
end
