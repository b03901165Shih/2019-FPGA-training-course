clear;
num_pat = 1024*4;

data_in = int32(randi([-2^29 2^29],1,num_pat));


in_path    = 'in.dat';
out_path = 'out.dat';
write2File = true;


%% Write out
if(write2File)
    % Write file
    fileID = fopen(in_path,'w');
    for j = 1:4:num_pat
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j+1)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j+2)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j+3)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'\n');
    end
    fclose(fileID);
    % Write file
    fileID = fopen(out_path,'w');
    for j = num_pat:-4:1
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j-1)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j-2)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'%s',char(dec2hex(typecast(int32(data_in(j-3)),'uint32'),8)-'0' + 48));
            fprintf(fileID,'\n');
    end
    fclose(fileID);
end
