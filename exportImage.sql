set image.col to :v1;
set current.client to :v2;
do $$
declare 
  client character varying(32):= current_setting('current.client');
  image_column character varying(30):= current_setting('image.col');
  table_name character varying(30);
  mimetype character varying(255);
  with_options character varying(20);
begin
  if substring(image_column, 1, 3) = 'si_' then
    image_column = substring(image_column, 4);
    table_name = 'ad_system_info';
    client = '0';
  else
    table_name = 'ad_clientinfo';
  end if;

  EXECUTE FORMAT('select mimetype from ad_image where ad_image_id = 
	   (select %I from %I where ad_client_id = %L)', image_column, table_name, client) INTO mimetype;
  if mimetype = 'image/svg+xml' then
    with_options = 'WITH BINARY';
  else 
    with_options = '';
  end if;

  -- export image information
  EXECUTE FORMAT('COPY (select encode(binarydata,''hex'') from ad_image where ad_image_id = 
	   (select %I from %I where ad_client_id = %L))
  TO ''/tmp/image.hex'' %s', image_column, table_name, client, with_options);

  -- export image metadata
  EXECUTE FORMAT('COPY (select width, height, mimetype from ad_image where ad_image_id = 
	   (select %I from %I where ad_client_id = %L))
  TO ''/tmp/image.data'' (DELIMITER ''|'')', image_column, table_name, client);
end$$;