set image.location to :v1;
set image.width to :v2;
set image.height to :v3; 
set image.mimetype to :v4;
set image.col to :v5;  
set current.client to :v6;  
do $$
declare 
  client character varying(32):= current_setting('current.client');
  org character varying(32):= '0';
  image character varying(200):= current_setting('image.location');
  p_result bytea:= '';
  r record;
  l_oid oid;
  width numeric:= current_setting('image.width');
  height numeric:= current_setting('image.height');
  mimetype character varying(255):= current_setting('image.mimetype');
  image_id character varying(32):= get_uuid();
  image_column character varying(30):= current_setting('image.col');
  table_name character varying(30);
begin
  select lo_import(image) into l_oid;
  for r in (select data from pg_largeobject where loid = l_oid order by pageno) loop
    p_result = p_result || r.data;
  end loop;
  perform lo_unlink(l_oid);
     
  insert into ad_image(
            ad_image_id, ad_client_id, ad_org_id, isactive, created, createdby, 
            updated, updatedby, name, imageurl, binarydata, width, height, mimetype)
            values (image_id, client, org, 'Y', now(), '100', 
            now(), '100', 'Image', null, p_result , width, height, mimetype);

  if substring(image_column, 1, 3) = 'si_' then
    image_column = substring(image_column, 4);
    table_name = 'ad_system_info';
    client = '0';
  else
    table_name = 'ad_clientinfo';
  end if;
  
  execute format ('update %I set %I = %L where ad_client_id = %L', table_name, image_column, image_id, client);
  
end$$;