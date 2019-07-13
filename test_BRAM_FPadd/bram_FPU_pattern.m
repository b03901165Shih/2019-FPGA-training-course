clear;
num_pat = 1024*4;

data_in = single(rand(1,num_pat)*2^20-2^19);

data_out = single(zeros(1, num_pat));
for i = 1:4:num_pat
    a = single(data_in(i)+data_in(i+1));
    b = single(data_in(i+2)+data_in(i+3));
    data_out(i+3) = single(a+b);
end

in_path    = 'in.dat';
out_path = 'out.dat';
write2File = true;


%% Write out
if(write2File)
    % Write file
    fileID = fopen(in_path,'w');
    for j = 1:4:num_pat
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_in(j)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_in(j+1)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_in(j+2)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_in(j+3)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'\n');
    end
    fclose(fileID);
    % Write file
    fileID = fopen(out_path,'w');
    for j = 1:4:num_pat
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_out(j)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_out(j+1)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_out(j+2)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(single(data_out(j+3)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'\n');
    end
    fclose(fileID);
end



