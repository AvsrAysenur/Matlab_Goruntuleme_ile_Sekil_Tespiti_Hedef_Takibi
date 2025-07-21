function kirmizi_Daire_Tespiti()
    fig = figure('Name', 'Kirmizi Daire Takip Sistemi (GUI)', ...
        'NumberTitle', 'off', 'Color', [0.1 0.1 0.1], ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100 100 950 650]);

    ax = axes('Parent', fig, 'Units', 'pixels', 'Position', [50 150 640 480]);
    axis off;

    konumLabel = uicontrol('Style', 'text', 'Parent', fig, ...
        'Position', [700 250 220 200], 'BackgroundColor', [0.2 0.2 0.2], ...
        'ForegroundColor', 'white', 'FontSize', 11, ...
        'HorizontalAlignment', 'left', 'String', 'Kirmizi Daire Konumu:');

    stopAlarmBtn = uicontrol('Style', 'togglebutton', 'String', 'Alarmi Durdur', ...
        'Position', [700 200 150 40], 'FontSize', 12, 'BackgroundColor', [0.8 0.2 0.2], 'ForegroundColor', 'white');

    screenshotBtn = uicontrol('Style', 'pushbutton', 'String', 'Screenshot Al', ...
        'Position', [700 150 150 40], 'FontSize', 12, 'BackgroundColor', [0.2 0.6 0.8], ...
        'ForegroundColor', 'white', 'Callback', @(~,~) screenshot(ax));

    closeBtn = uicontrol('Style', 'pushbutton', 'String', 'Kapat', ...
        'Position', [700 100 150 40], 'FontSize', 12, 'BackgroundColor', [0.5 0.1 0.1], ...
        'ForegroundColor', 'white', 'Callback', @(~,~) close(fig));

    uicontrol('Style', 'text', 'Parent', fig, 'Position', [700 570 150 20], ...
        'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'white', ...
        'String', 'Kamera Kaynagi:', 'HorizontalAlignment', 'left');

    cameraPopup = uicontrol('Style', 'popupmenu', 'Parent', fig, 'Position', [700 540 200 25], ...
        'String', {'Bilgisayar Kamerasi', 'Telefon Kamerasi (IP)'}, 'Callback', @(src,~) toggleIP(src));

    ipInput = uicontrol('Style', 'edit', 'Parent', fig, 'Position', [700 500 200 25], ...
        'BackgroundColor', 'white', 'String', 'http://192.168.1.25:8080/video', 'Visible', 'off');

    uicontrol('Style', 'pushbutton', 'Parent', fig, 'Position', [700 460 200 30], ...
        'String', 'Kamerayi Baslat', 'FontSize', 12, 'Callback', @(~,~) startCamera());

    function toggleIP(src)
        ipInput.Visible = src.Value == 2;
    end

    function startCamera()
        cla(ax);
        try
            if cameraPopup.Value == 1
                cam = webcam;
            else
                cam = ipcam(ipInput.String);
            end
        catch
            errordlg('Kamera baslatilamadi. Lutfen baglantiyi kontrol edin.', 'Kamera Hatasi');
            return;
        end
        runTrackingLoop(cam, fig, ax, stopAlarmBtn, konumLabel);
    end

    function screenshot(axHandle)
        frame = getimage(axHandle);
        if isempty(frame)
            warndlg('Kayit icin gecerli bir goruntu yok.', 'Uyari'); return;
        end
        [file,path] = uiputfile({'*.png';'*.jpg';'*.bmp'}, 'Ekran Goruntusunu Kaydet');
        if isequal(file,0), return; end
        imwrite(frame, fullfile(path,file));
    end
end

function runTrackingLoop(cam, fig, ax, stopAlarmBtn, konumLabel)
    prevCenter = [];
    trajectory = []; % Hareket çizgisi için
    prevTime = tic;
    alarmCaldi = false;

    renkler = {
        'Kirmizi', [0.95 1.0; 0.0 0.05], [0.4 1], [0.4 1];
        'Sari',    [0.10 0.17], [0.4 1], [0.4 1];
        'Mavi',    [0.55 0.70], [0.3 1], [0.2 1];
        'Siyah',   [0 1],       [0 0.5], [0 0.25];
        'Lila',    [0.75 0.85], [0.2 1], [0.2 1];
        'Lacivert',[0.58 0.65], [0.3 1], [0.1 0.4];
        'Yesil',   [0.25 0.45], [0.3 1], [0.3 1];
    };

    while isvalid(fig)
        img = snapshot(cam);
        img = imresize(img, 0.75);
        hsv = rgb2hsv(imgaussfilt(img, 1.5));
        imshow(img, 'Parent', ax); hold(ax, 'on');
        alarmDurumu = false;

        for i = 1:size(renkler, 1)
            hRanges = renkler{i, 2};
            sRange = renkler{i, 3};
            vRange = renkler{i, 4};

            maskTotal = false(size(hsv(:,:,1)));
            for h = 1:size(hRanges,1)
                hRange = hRanges(h,:);
                mask = hsv(:,:,1) >= hRange(1) & hsv(:,:,1) <= hRange(2) & ...
                       hsv(:,:,2) >= sRange(1) & hsv(:,:,2) <= sRange(2) & ...
                       hsv(:,:,3) >= vRange(1) & hsv(:,:,3) <= vRange(2);
                maskTotal = maskTotal | mask;
            end

            maskTotal = bwareaopen(imfill(maskTotal, 'holes'), 300);
            stats = regionprops(maskTotal, 'Centroid', 'BoundingBox', 'Area', 'Perimeter', 'Extent', 'MajorAxisLength', 'MinorAxisLength');

            for j = 1:length(stats)
                bbox = stats(j).BoundingBox;
                centroid = stats(j).Centroid;
                area = stats(j).Area;
                perimeter = stats(j).Perimeter;
                extent = stats(j).Extent;
                major = stats(j).MajorAxisLength;
                minor = stats(j).MinorAxisLength;

                circularity = 4 * pi * area / (perimeter^2);
                aspectRatio = major / minor;

                if circularity > 0.75 && abs(aspectRatio - 1) < 0.3
                    shape = 'Daire';
                elseif extent > 0.85 && abs(bbox(3) - bbox(4)) < 10
                    shape = 'Kare';
                elseif extent > 0.75 && abs(bbox(3) - bbox(4)) >= 10
                    shape = 'Dikdortgen';
                elseif extent > 0.4 && extent < 0.65 && aspectRatio > 0.8 && aspectRatio < 1.4
                    shape = 'Ucgen';
                else
                    shape = 'Bilinmeyen';
                end

                renkAdi = renkler{i,1};
                label = [renkAdi ' ' shape];

                rectangle(ax, 'Position', bbox, 'EdgeColor', 'g', 'LineWidth', 2);
                text(ax, centroid(1), centroid(2), label, 'Color', 'w', 'FontSize', 11, 'BackgroundColor', 'k');

                % Sadece kirmizi daire takip edilir
                if strcmp(renkAdi, 'Kirmizi') && strcmp(shape, 'Daire')
                    alarmDurumu = true;
                    direction = [0 0]; speed = 0;
                    if ~isempty(prevCenter)
                        dt = toc(prevTime);
                        direction = centroid - prevCenter;
                        speed = norm(direction)/dt;
                    end
                    prevCenter = centroid;
                    prevTime = tic;

                    trajectory(end+1, :) = centroid; %#ok<AGROW>

                    if ~alarmCaldi && ~stopAlarmBtn.Value
                        sound(sin(1:3000)); alarmCaldi = true;
                    elseif stopAlarmBtn.Value
                        alarmCaldi = false;
                    end

                    konumLabel.String = sprintf('Kirmizi Daire Konumu:\nX: %.0f\nY: %.0f\n\nYon: [%.1f, %.1f]\n\nHiz: %.2f px/s', ...
                        centroid(1), centroid(2), direction(1), direction(2), speed);
                end
            end
        end

        % Kırmızı çizgi ile hareket izi
        if size(trajectory, 1) >= 2
            plot(ax, trajectory(:,1), trajectory(:,2), 'r-', 'LineWidth', 2);
        end

        if ~alarmDurumu
            konumLabel.String = 'Kirmizi Daire Konumu:\nYok';
            alarmCaldi = false;
            prevCenter = [];
        end

        hold(ax, 'off');
        pause(0.01);
    end
end
